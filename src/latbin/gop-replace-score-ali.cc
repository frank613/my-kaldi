#include "util/common-utils.h"
#include "base/kaldi-common.h"


int main(int argc, char *argv[]) {

    try{
        using namespace kaldi;
        typedef kaldi::int32 int32;
        typedef kaldi::Vector<kaldi::BaseFloat> Fvector;
        //typedef kaldi::Vector<kaldi::int32> Ivector;

    const char *usage =
        "Rewrite alignment score file using the feature slice information and its new scores\n"
        "Usgae: gop-replace-score-ali aliscore-rspecifier phoneme-aliscore-rspecifier feat-rspecifier new-aliscore-wspecifier";

    ParseOptions po(usage);
    //BaseFloat lm2acoustic_scale = 0.0;
    //po.Register("lm2acoustic-scale", &lm2acoustic_scale, "Add this times original LM costs to acoustic costs");

    po.Read(argc, argv);

    if (po.NumArgs() != 4) {
      po.PrintUsage();
      exit(1);
    }

    std::string aliscore_rspecifier = po.GetArg(1),
        pscore_rspecifier = po.GetArg(2), 
        feat_rspecifier = po.GetArg(3),
        ali_wspecifier= po.GetArg(4);

    SequentialBaseFloatVectorReader aliscore_reader(aliscore_rspecifier);
    //RandomAccessBaseFloatVectorReader aliscore_reader(aliscore_rspecifier);
    //RandomAccessBaseFloatVectorReader pscore_reader(pscore_rspecifier);  
    RandomAccessBaseFloatMatrixReader slice_reader(feat_rspecifier);
    BaseFloatVectorWriter score_writer(ali_wspecifier);

    if (dynamic_cast<RandomAccessTableReaderScriptImpl<KaldiObjectHolder<Matrix<BaseFloat>>>*>(slice_reader.impl_) == 0){
      KALDI_ERR << "the input file for feats must be a SCP file.";
    }
    // std::set<std::string> modified_utts; 
    // for (; !pscore_reader.Done(); pscore_reader.Next()) {
    //     std::string uttid = pscore_reader.Key();
    //     if (!slice_reader.HasKey(uttid)){
    //       KALDI_WARN << "found phone score but can't load slice information: uttid " << uttid;
    //       continue; 
    //     }
    //     //strip the slice in the uttid
    //     std::string uttid_orig = uttid.substr(0, uttid.find_last_of('-') - 1);
    //     if (!aliscore_reader.HasKey(uttid_orig)){
    //       KALDI_WARN << "found phone score but can't load original score: uttid " << uttid;
    //       continue;
    //     }
    //     const Fvector &pvector_score = pscore_reader.Value();
    //     std::string s_range = dynamic_cast<RandomAccessTableReaderScriptImpl<KaldiObjectHolder<Matrix<BaseFloat>>>*>(slice_reader.impl_)->Range(uttid);
    //     std::size_t found = s_range.find(":");
    //     if ( found == std::string::npos){
    //       KALDI_ERR << "Read slice Error: uttid " << uttid;
    //     }
    //     int32 start = std::stoi(s_range.substr(0, found-1));
    //     int32 end = std::stoi(s_range.substr(found+1));
    //     KALDI_ASSERT( pvector_score.Dim() == end - start + 1); //the length of the p-vector should be the same as the range
    //     //replace the value
    //     Fvector temp_vect = aliscore_reader.Value(uttid_orig);
    //     temp_vect.Range(start, end - start + 1 ).CopyFromVec(pscore_reader.Value());
    //     score_writer.Write(uttid_orig, temp_vect);
    //     modified_utts.insert(uttid_orig);
    // }

    //write unmodified entries



    for (; !aliscore_reader.Done(); aliscore_reader.Next()) {
        std::string uttid = aliscore_reader.Key();
        Fvector oVector_copy = aliscore_reader.Value(); 
        SequentialBaseFloatVectorReader pscore_reader(pscore_rspecifier);  
        int32 modify_count = 0;
        for (; !pscore_reader.Done(); pscore_reader.Next()){
          std::string uttid_ext = pscore_reader.Key();
          //std::string uttid_cur = uttid_ext.substr(0, uttid_ext.find_last_of('-'));
          //KALDI_LOG << "uttid_ext: " << uttid_ext << " original uttid: " << uttid_cur;
          if (uttid == uttid_ext.substr(0, uttid_ext.find_last_of('-'))){ //the same uttid
            if (!slice_reader.HasKey(uttid_ext)){
              KALDI_WARN << "found phone score but can't load slice information" << uttid_ext;
              continue;
            }
            //extract the slice and rewrite the score
            std::string s_range = dynamic_cast<RandomAccessTableReaderScriptImpl<KaldiObjectHolder<Matrix<BaseFloat>>>*>(slice_reader.impl_)->Range(uttid_ext);
            if (s_range == ""){
              KALDI_WARN << "found phone score but can't load slice information" << uttid_ext;
              continue;
            }
            int32 start = std::stoi(s_range.substr(0, s_range.find(":")));
            int32 end = std::stoi(s_range.substr(s_range.find(":")+1, s_range.length()-s_range.find(":")-1));
            KALDI_ASSERT( pscore_reader.Value().Dim() == end - start + 1); //the length of the p-vector should be the same as the range
            oVector_copy.Range(start, end - start + 1 ).CopyFromVec(pscore_reader.Value());
            modify_count += 1;
          }
        }
        score_writer.Write(uttid, oVector_copy);
        KALDI_LOG << "write socre for id: " << uttid << ", " << modify_count << " phonemes modified";
    }
        
        // else {
        //   KALDI_WARN << "rewrite score for the utt " << uttid;
        //   //get the score
        //   const Fvector &pvector_score = pscore_reader.Value(uttid);
        //   //get the range
        //   if (!slice_reader.HasKey(uttid)){
        //     KALDI_WARN << "found phone score but can't load slice information" << uttid;
        //     score_writer.Write(uttid, oVector_ref);
        //     continue;
        //   }
        //   else {
        //     //having not chcked if the polymorphism is correctly inferred for the SCP file
        //     std::string s_range = dynamic_cast<RandomAccessTableReaderScriptImpl<KaldiObjectHolder<Matrix<BaseFloat>>>*>(slice_reader.impl_)->Range(uttid);
        //     if (s_range == ""){
        //       KALDI_WARN << "found phone score but can't load slice information" << uttid;
        //       score_writer.Write(uttid, oVector_ref);
        //       continue;
        //     }
        //     int32 start = std::stoi(s_range.substr(0, s_range.find(":")));
        //     int32 end = std::stoi(s_range.substr(s_range.find(":")+1, s_range.length()-s_range.find(":")-1));
        //     KALDI_ASSERT( pvector_score.Dim() == end - start + 1); //the length of the p-vector should be the same as the range
        //     //replace the vector
        //     Fvector newVec = oVector_ref;
        //     newVec.Range(start, end - start + 1 ).CopyFromVec(pvector_score);
        //     //write
        //     score_writer.Write(uttid, newVec);
        //   }
        // }
    }catch(const std::exception &e) {
    std::cerr << e.what();
    return -1;
  }
}
