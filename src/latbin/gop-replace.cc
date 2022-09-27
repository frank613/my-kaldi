#include "base/kaldi-common.h"
#include "util/common-utils.h"
#include "fstext/fstext-lib.h"
#include "lat/kaldi-lattice.h"
#include "latbin/gop-base.cc"

//define a new GOP class (with substitution information)for writting according to kaldi IO fasion
typedef std::vector<std::tuple<int32, bool, double>> GOPSub; //(id, is_substituted, gop_socre)
class GOPSubHolder {
  
  public:
    typedef GOPSub T; //GOPresHolder type T will be referenced by the TableWriter template class 
    GOPSubHolder() { t_ = NULL; }
    static bool Write(std::ostream &os, bool binary, const T &t) {
      if (binary) {
        KALDI_ERR << "GOP writer doesn't support binaray write, use text in command line";
      } else {
        // Text-mode output. 
        os << '\n';
        for (auto it = t.begin(); it != t.end(); ++it){
          os << std::distance(t.begin(), it) <<  "\t" << std::get<0>(*it) << "\t"  << std::get<1>(*it) << "\t" << std::get<2>(*it) << "\n";
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
  private:
    T *t_;
};

typedef kaldi::TableWriter<GOPSubHolder> GOPSubWriter;

int main(int argc, char *argv[]) {

    try{
        using namespace kaldi;
        typedef kaldi::int32 int32;
        using fst::SymbolTable;
        using fst::VectorFst;
        using fst::StdArc;

    const char *usage =
        "calculating the GOP based on the given alignment (after-substitution) and topsorted 1-best (non-compact)lattice, the lattice should be non-compact, \ 
        the original GOP file (after int2symbol) shoud be also provided for retrieving the substituded phonemes from phoneme-number \n"
        "Usgae: gop-replace ali-rspecifier lattice-rspecifier gop-rspeicifier subst-phoneme gop-wspecifier";

    ParseOptions po(usage);
    //BaseFloat lm2acoustic_scale = 0.0;
    //po.Register("lm2acoustic-scale", &lm2acoustic_scale, "Add this times original LM costs to acoustic costs");

    po.Read(argc, argv);

    if (po.NumArgs() != 5) {
      po.PrintUsage();
      exit(1);
    }

    std::string ali_rspecifier = po.GetArg(1),
        lat_rspecifier = po.GetArg(2),
        gop_rspecifier = po.GetArg(3),
        sub_phoneme = po.GetArg(4),
        gop_wspecifier= po.GetArg(4);

    SequentialLatticeReader lattice_reader(lat_rspecifier);
    RandomAccessBaseFloatVectorReader ali_reader(ali_rspecifier);
    GOPReader gop_reader(gop_rspecifier);
    // BaseFloatVectorWriter gop_writer(gop_wspecifier);
    GOPSubWriter gop_writer(gop_wspecifier);

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
        for (StateId s = 0; s < num_states; s++) {
            for (fst::MutableArcIterator<Fst> aiter(lat_ptr, s);!aiter.Done();aiter.Next()){
              Arc arc = aiter.Value();
              //KALDI_LOG << "processing arc: " << s <<"the next state is " << arc.nextstate;
              if (arc.nextstate != s + 1){
                  KALDI_ERR << "Lattice is not top-sorted or linear, interrupted";
              }
              if (arc.ilabel != 0){
                  num_frame++;
                  if (num_frame > num_score.Dim()){
                    KALDI_ERR << "decoding length greather than the alignment length, interrupted";
                  }
                  denom_score.Set(arc.weight.Value2());
              }
            } 
        }
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
        gop_per_frame.AddVec(1, denom_score); //num_score is negative, but denom is positive, the difference is assumed to be negative  
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
        for(int n = 0, start_pos = 1, last = vec_time[0], current = vec_time[0]; n < length; n++ ){
          current = vec_time[n];
          if (last == current){ //still in the same phone
            ; //do nothing
          }
          else {
            results.push_back(std::make_pair(last, gop_per_frame.Range(start_pos, n+1-start_pos).Sum()/(n+1-start_pos)));
            start_pos = n+1; // Kaldi vector index starts from 1
          }
          last = current;
          if (n == length -1){ //push everything at the last frame
            results.push_back(std::make_pair(last, gop_per_frame.Range(start_pos, n+1-start_pos).Sum()/(n+1-start_pos)));
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
