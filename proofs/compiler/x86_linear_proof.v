(* ** License
 * -----------------------------------------------------------------------
 * Copyright 2016--2017 IMDEA Software Institute
 * Copyright 2016--2017 Inria
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 * ----------------------------------------------------------------------- *)

From mathcomp Require Import all_ssreflect all_algebra.
Require Import expr psem psem_facts linear linear_sem linear_proof.
Require Import x86_decl x86_instr_decl x86_linear x86_variables.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Lemma wf_x86_allocate_stack_frame :
  forall rspi sz,
    isSome (is_lopn (x86_allocate_stack_frame rspi sz)).
Proof. done. Qed.

Lemma spec_x86_allocate_stack_frame :
  forall (lp: lprog) (s: estate) sp_rsp ii fn pc ts sz,
    let rsp := vid sp_rsp in
    let vm := evm s in
    let i := x86_allocate_stack_frame (VarI rsp xH) sz in
    let ts' := pword_of_word (ts + wrepr Uptr sz) in
    let s' := with_vm s (vm.[rsp <- ok ts'])%vmap in
    (vm.[rsp])%vmap = ok (pword_of_word ts)
    -> eval_instr lp x86_linear_params (MkLI ii i) (of_estate s fn pc)
       = ok (of_estate s' fn pc.+1).
Proof.
  move=> lp s sp_rsp ii fn pc ts sz.
  move=> /= Hvm.
  rewrite /eval_instr /= /sem_sopn /=.
  rewrite /get_gvar /get_var /on_vu /=.
  rewrite Hvm /=.
  rewrite pword_of_wordE.
  by rewrite 3!zero_extend_u.
Qed.

Lemma wf_x86_free_stack_frame :
  forall rspi sz,
    isSome (is_lopn (x86_free_stack_frame rspi sz)).
Proof. done. Qed.

Lemma spec_x86_free_stack_frame :
  forall (lp: lprog) (s: estate) sp_rsp ii fn pc ts sz,
    let rsp := vid sp_rsp in
    let vm := evm s in
    let i := x86_free_stack_frame (VarI rsp xH) sz in
    let ts' := pword_of_word (ts - wrepr Uptr sz) in
    let s' := with_vm s (vm.[rsp <- ok ts'])%vmap in
    (vm.[rsp])%vmap = ok (pword_of_word ts)
    -> eval_instr lp x86_linear_params (MkLI ii i) (of_estate s fn pc)
       = ok (of_estate s' fn pc.+1).
Proof.
  move=> lp s sp_rsp ii fn pc ts sz.
  move=> /= Hvm.
  rewrite /eval_instr /= /sem_sopn /=.
  rewrite /get_gvar /get_var /on_vu /=.
  rewrite Hvm /=.
  rewrite pword_of_wordE.
  by rewrite 3!zero_extend_u.
Qed.

Lemma wf_x86_ensure_rsp_alignment :
  forall x ws,
    isSome (is_lopn (x86_ensure_rsp_alignment x ws)).
Proof. done. Qed.

Definition spec_x86_ensure_rsp_alignment :
forall (lp: lprog) (s1: estate) rsp_id ws ts' ii fn pc,
  let vrsp := Var (sword Uptr) rsp_id in
  let vrspi := VarI vrsp xH in
  let al := wrepr Uptr (- wsize_size ws) in
  let rsp' := wand ts' al in
  let vm' := (evm s1)
             .[{| vtype := sbool; vname := "OF"%string |}
               <- ok false]
             .[{| vtype := sbool; vname := "CF"%string |}
               <- ok false]
             .[{| vtype := sbool; vname := "SF"%string |}
               <- ok (SF_of_word rsp')]
             .[{| vtype := sbool; vname := "PF"%string |}
               <- ok (PF_of_word rsp')]
             .[{| vtype := sbool; vname := "ZF"%string |}
               <- ok (ZF_of_word rsp')]
             .[vrsp <- ok (pword_of_word rsp')]%vmap
  in
  get_var (evm s1) vrsp = ok (Vword ts')
  -> eval_instr
       lp
       x86_linear_params
       (MkLI ii (x86_ensure_rsp_alignment vrspi ws))
       (of_estate s1 fn pc)
     = ok (of_estate (with_vm s1 vm') fn pc.+1).
Proof.
  move=> lp s1 rsp_id ws ts' sp_rsp ii fn.
  move=> vrsp vrspi al /= Hvrsp.
  rewrite /eval_instr /= /sem_sopn /= /get_gvar /=.
  rewrite Hvrsp /=.
  by rewrite !zero_extend_u pword_of_wordE.
Qed.


Lemma wf_x86_lassign :
  forall x ws e,
    isSome (is_lopn (x86_lassign x ws e)).
Proof. done. Qed.

Lemma spec_x86_lassign :
  forall (lp: lprog) (s1 s2: estate) x e ws ws'
         (w: word ws) (w': word ws') ii fn pc,
    sem_pexpr [::] s1 e = ok (Vword w')
    -> truncate_word ws w' = ok w
    -> write_lval [::] x (Vword w) s1 = ok s2
    -> eval_instr
         lp
         x86_linear_params
         (MkLI ii (x86_lassign x ws e))
         (of_estate s1 fn pc)
       = ok (of_estate s2 fn pc.+1).
Proof.
  move=> lp s1 s2 x e ws ws' w w' ii fn pc.
  move=> Hsem_pexpr Htruncate_word Hwrite_lval.
  rewrite /eval_instr /= /sem_sopn /=.
  rewrite to_estate_of_estate.
  rewrite Hsem_pexpr /=.
  rewrite /exec_sopn /=.
  case: ws w Htruncate_word Hwrite_lval
    => /= ? Htruncate_word Hwrite_lval;
    rewrite Htruncate_word /=;
    rewrite Hwrite_lval /=;
    done.
Qed.

Definition h_x86_linear_params : h_linear_params x86_linear_params.
Proof.
  split.
  - exact: wf_x86_allocate_stack_frame.
  - exact: spec_x86_allocate_stack_frame.
  - exact: wf_x86_free_stack_frame.
  - exact: spec_x86_free_stack_frame.
  - exact: wf_x86_ensure_rsp_alignment.
  - exact: spec_x86_ensure_rsp_alignment.
  - exact: wf_x86_lassign.
  - exact: spec_x86_lassign.
Qed.
