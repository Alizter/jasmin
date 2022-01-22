type state = unit

(* FIXME syscall : I don't think that this implementation is a good one.
   But it allows to have something quick for the evaluator, so 
   it is not crutial  
*)

let _ = 
  Random.self_init ()
 
let initial_state () = () 

let random_char _ = 
  let n = Random.int 256 in
  Word0.wrepr Wsize.U8 (CoreConv.z_of_int n)

let get_random (s : state) (z:BinNums.coq_Z) = 
  let n = CoreConv.int_of_z z in
  assert (0 <= n);  
  s, List.init n random_char 