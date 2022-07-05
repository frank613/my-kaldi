#include "base/kaldi-common.h"
#include "util/common-utils.h"
#include "fstext/fstext-lib.h"
#include "lat/kaldi-lattice.h"

int main(int argc, char *argv[]) {

    try{
        using namespace kaldi;
        typedef kaldi::int32 int32;
        using fst::SymbolTable;
        using fst::VectorFst;
        using fst::StdArc;

    const char *usage =
        "calculating the GOP based on the given aliment and lattice, the lattice should be non-compact\n"
        "Usgae: compute-gop ali-repeicier lattice-rspecifier model-rspecifier gop-wspecifier";

    ParseOptions po(usage);
    //BaseFloat lm2acoustic_scale = 0.0;
    //po.Register("lm2acoustic-scale", &lm2acoustic_scale, "Add this times original LM costs to acoustic costs");

    po.Read(argc, argv);

    if (po.NumArgs() != 4) {
      po.PrintUsage();
      exit(1);
    }

    std::string ali_rspecifier = po.GetArg(1),
        lat_rspecifier = po.GetArg(2),
        gop_wspecifier= po.GetArg(3);

    SequentialLatticeReader lattice_reader(lat_rspecifier);

    //GOPWriter compact_lattice_writer(gop_wspecifier);
    typedef fst::ArcTpl<LatticeWeight> Arc;
    typedef typename Arc::StateId StateId;
    typedef fst::MutableFst<Arc> Fst;
    for (; !lattice_reader.Done(); lattice_reader.Next()) {
        Lattice *lat_ptr = &lattice_reader.Value();
        StateId num_states = lat_ptr->NumStates();
          for (StateId s = 0; s < num_states; s++) {
              for (fst::MutableArcIterator<Fst> aiter(lat_ptr, s);!aiter.Done();aiter.Next()){
                Arc arc = aiter.Value();
              }
                
          }

    }

    }catch(const std::exception &e) {
    std::cerr << e.what();
    return -1;
  }
}