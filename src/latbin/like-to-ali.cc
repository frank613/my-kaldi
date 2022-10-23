#include "util/common-utils.h"
#include "base/kaldi-common.h"


int main(int argc, char *argv[]) {

    try{
        using namespace kaldi;
        typedef kaldi::int32 int32;
        typedef kaldi::Vector<kaldi::BaseFloat> Fvector;
        typedef kaldi::Matrix<kaldi::BaseFloat> Fmatrix;
        //typedef kaldi::Vector<kaldi::int32> Ivector;

    const char *usage =
        "Convert likelihood matrix to alignment score given pdf id\n"
        "Usgae: like-to-ali pdf-id matrix-rspecifier aliscore-wspecifier";

    ParseOptions po(usage);

    po.Read(argc, argv);

    if (po.NumArgs() != 3) {
      po.PrintUsage();
      exit(1);
    }

    std::string pdf_id_str = po.GetArg(1);
    std::string matrix_rspecifier = po.GetArg(2), 
        ali_wspecifier= po.GetArg(3);


    SequentialBaseFloatMatrixReader like_reader(matrix_rspecifier);
    BaseFloatVectorWriter score_writer(ali_wspecifier);
    int32 pdf_id = std::stoi(pdf_id_str);

    for (; !like_reader.Done(); like_reader.Next()) {
        std::string uttid = like_reader.Key();
        Fmatrix like_mat = like_reader.Value(); 
        Fvector like_vec(like_mat.NumRows());
        //row = frame, column = pdf
        like_vec.CopyColFromMat(like_mat, pdf_id);
        score_writer.Write(uttid, like_vec);
        KALDI_LOG << "write socre for id: " << uttid << " from the matrix which has " << like_mat.NumRows() << " rows.";
    }
    }catch(const std::exception &e) {
    std::cerr << e.what();
    return -1;
  }
}
