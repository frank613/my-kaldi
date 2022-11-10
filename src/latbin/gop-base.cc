#include "base/kaldi-common.h"
#include "util/common-utils.h"
#include "fstext/fstext-lib.h"
#include "lat/kaldi-lattice.h"

//define a new GOP class for writting according to kaldi IO fasion
typedef std::vector<std::pair<int32, double>> GOPres;
class GOPresHolder {
  
  public:
    typedef GOPres T; //GOPresHolder type T will be referenced by the TableWriter template class 
    GOPresHolder() { t_ = NULL; }
    static bool Write(std::ostream &os, bool binary, const T &t) {
      if (binary) {
        KALDI_ERR << "GOP writer doesn't support binaray write, use text in command line";
      } else {
        // Text-mode output. 
        os << '\n';
        for (auto it = t.begin(); it != t.end(); ++it){
          os << std::distance(t.begin(), it) <<  "\t" << it->first << "\t" << it->second << "\n";
        }
        if (os.fail())
          KALDI_WARN << "Stream failure detected.";
        // Write another newline as a terminating character.  The read routine will
        // detect this [this is a Kaldi mechanism, not somethig in the original
        // OpenFst code].
        os << '\n';
        return os.good();
      }
    }
    
    bool Read(std::istream &is) {
          Clear(); // in case anything currently stored.
          int c = is.peek();
          if (c == -1) {
            KALDI_WARN << "End of stream detected";
            return false;
          } else if (isspace(c)) { // The text form of the lattice begins
            // with space (normally, '\n'), so this means it's text (the binary form
            // cannot begin with space because it starts with the FST Type() which is not
            // space).
            return ReadGop(is, false, &t_);
          } else if (c != 214) { // 214 is first char of FST magic number,
            // on little-endian machines which is all we support (\326 octal)
            KALDI_WARN << "Reading compact lattice: does not appear to be an FST "
                      << " [non-space but no magic number detected], file pos is "
                      << is.tellg();
            return false;
          } else {
            return ReadGop(is, true, &t_);
          }
     }

    bool ReadGop(std::istream &is, bool binary, GOPres **gopRes) {
      KALDI_ASSERT(*gopRes == NULL);
      if (binary) {
        KALDI_ERR << "GOP reader doesn't support binaray read currently, use text in command line";
      }
      else{
        // The next line would normally consume the \r on Windows, plus any
        // extra spaces that might have got in there somehow.
        while (std::isspace(is.peek()) && is.peek() != '\n') is.get(); 
        if (is.peek() == '\n') is.get(); // consume the newline.
        else { // saw spaces but no newline.. this is not expected.
          KALDI_WARN << "Reading GOP text: unexpected sequence of spaces "
                 << " at file position " << is.tellg();
          return false;
        } 

        *gopRes = new GOPres;  // don't forget to free after using it
        size_t nline = 0;
        std::string line;
        std::vector<string> col;
        string separator = FLAGS_fst_field_separator + "\r\n";
        kaldi::SplitStringToVector(line, separator.c_str(), true, &col);
        while (std::getline(is, line)) {
          nline++;
          if (col.size() == 0) break; // Empty line is a signal to stop, in our
          // archive format.
          if (col.size() != 2) {
            KALDI_WARN << "Reading GOP: bad line in GOP: " << line;
            delete *gopRes;
            *gopRes = NULL;
            break;
          }
          int32_t phoneme;
          if (!kaldi::ConvertStringToInteger(col[0], &phoneme)){
              KALDI_WARN << "Reading GOP: bad line in GOP: " << line;
              delete *gopRes;
              *gopRes = NULL;
              break;
          }
          double_t gScore;
          if (!kaldi::ConvertStringToReal(col[1], &gScore)){
              KALDI_WARN << "Reading GOP: bad line in GOP: " << line;
              delete *gopRes;
              *gopRes = NULL;
              break;
          }
          (*gopRes)->push_back(std::make_pair(phoneme, gScore));
        }
      }
      return (*gopRes != NULL);
    }

    void Clear() {  delete t_; t_ = NULL; }
    
  private:
    T *t_;
};

typedef kaldi::TableWriter<GOPresHolder> GOPWriter;
typedef kaldi::SequentialTableReader<GOPresHolder> GOPReader;

int main(int argc, char *argv[]) {

    try{
        using namespace kaldi;
        typedef kaldi::int32 int32;
        using fst::SymbolTable;
        using fst::VectorFst;
        using fst::StdArc;

    const char *usage =
        "calculating the GOP based on the given alignment and topsorted 1-best (non-compact)lattice, the lattice should be non-compact\n"
        "Usgae: compute-gop ali-rspecifier time-align-rspecifier lattice-rspecifier gop-wspecifier";

    ParseOptions po(usage);
    //BaseFloat lm2acoustic_scale = 0.0;
    //po.Register("lm2acoustic-scale", &lm2acoustic_scale, "Add this times original LM costs to acoustic costs");

    po.Read(argc, argv);

    if (po.NumArgs() != 4) {
      po.PrintUsage();
      exit(1);
    }

    std::string ali_rspecifier = po.GetArg(1),
        timing_rspecifier = po.GetArg(2), //read the phone-alignment file for grouping the gop scores
        lat_rspecifier = po.GetArg(3),
        gop_wspecifier= po.GetArg(4);

    SequentialLatticeReader lattice_reader(lat_rspecifier);
    RandomAccessBaseFloatVectorReader ali_reader(ali_rspecifier);
    RandomAccessInt32VectorReader time_reader(timing_rspecifier);
    // BaseFloatVectorWriter gop_writer(gop_wspecifier);
    GOPWriter gop_writer(gop_wspecifier);

    typedef fst::ArcTpl<LatticeWeight> Arc;
    typedef typename Arc::StateId StateId;
    typedef fst::MutableFst<Arc> Fst;
    typedef kaldi::Vector<kaldi::BaseFloat> Fvector;
    //typedef kaldi::Vector<kaldi::int32> Ivector;

    for (; !lattice_reader.Done(); lattice_reader.Next()) {
        string uttid = lattice_reader.Key();
        Lattice *lat_ptr = &lattice_reader.Value();
        StateId num_states = lat_ptr->NumStates();
        int num_frame {0};
        if (!ali_reader.HasKey(uttid)){
          KALDI_WARN << "the utt " << uttid << " can not be found in the alignment, skipped";
          continue;   
        }
        if (!time_reader.HasKey(uttid)){
          KALDI_WARN << "the utt " << uttid << " can not be found in the timing alignment, skipped";
          continue;   
        }
        KALDI_LOG << "processing" << uttid;
        const Fvector &num_score = ali_reader.Value(uttid); //vector for the numerator score
        Fvector denom_score(num_states); //vector to store the scores in the denominator
	//KALDI_LOG << "DENOM: "<< denom_score << std::endl;
        for (StateId s = 0; s < num_states; s++) {
            for (fst::MutableArcIterator<Fst> aiter(lat_ptr, s);!aiter.Done();aiter.Next()){
              Arc arc = aiter.Value();
              //KALDI_LOG << "processing arc: " << s <<"the next state is " << arc.nextstate;
              if (arc.nextstate != s + 1){
                  KALDI_ERR << "Lattice is not top-sorted or linear, interrupted";
              }
              if (arc.ilabel != 0){
                  denom_score(num_frame) = arc.weight.Value2();
                  num_frame++;
                  if (num_frame > num_score.Dim()){
                    KALDI_ERR << "decoding length greather than the alignment length, interrupted";
                  }
                  //denom_score.Set(arc.weight.Value2());
              }
            } 
        }
	//KALDI_LOG  << "DENOM: "<< denom_score << std::endl;
        if ( num_frame == 0){
            KALDI_WARN << "skipped because no acoustic score generated from this uttid: " << uttid;
            continue;
        }
        if ( num_frame != num_score.Dim()){
            KALDI_ERR << "decoding length is not the same as alignment length, interrupted: " << num_frame << " vs " << num_score.Dim();
        }
        denom_score.Resize(num_frame, kaldi::kCopyData);
        Fvector gop_per_frame; 
        gop_per_frame = num_score;
        gop_per_frame.AddVec(1, denom_score); //num_score is negative, but denom is positive in the Lattice, the difference is assumed to be negative  
        // gop_writer.Write(uttid, gop_per_frame);
        //KALDI_LOG << uttid << ": has " << num_frame << "frames";

        //grouping scores to phones
        const std::vector<int32> &vec_time = time_reader.Value(uttid);
        int length = vec_time.size();
        if ( num_frame != length){
            KALDI_ERR << "decoding length is not the same as alignment length while grouping, interrupted: " << num_frame << " vs " << num_score.Dim();
        }
        //pair <phone : average_score>  std::vector<std::pair<int32, double>>
        GOPres results;
        //for(int n = 0, start_pos = 1, last = vec_time[0], current = vec_time[0]; n < length; n++ ){
        for(int n = 0, start_pos = 0, last = vec_time[0], current = vec_time[0]; n < length; n++ ){
          current = vec_time[n];
          if (last == current){ //still in the same phone
            ; //do nothing
          }
          else {
            results.push_back(std::make_pair(last, gop_per_frame.Range(start_pos, n-start_pos).Sum()/(n-start_pos)));
            start_pos = n; // Kaldi vector index starts from 0
            //start_pos = n+1; // Kaldi vector index starts from 1
          }
          last = current;
          if (n == length -1){ //push everything at the last frame
            results.push_back(std::make_pair(last, gop_per_frame.Range(start_pos, n-start_pos).Sum()/(n-start_pos)));
          }
        }
        //write out
        gop_writer.Write(uttid, results);
    }

    }catch(const std::exception &e) {
    std::cerr << e.what();
    return -1;
  }
}
