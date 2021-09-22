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
From CoqWord Require Import ssrZ.
Require Import
  expr
  memory_model
  psem
  stack_alloc_proof_2
  x86_stack_alloc.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Section X86_PROOF.

  Variable (P' : sprog).
  Hypothesis P'_globs : P'.(p_globs) = [::].

  Lemma lea_ptrP s1 e i x ofs w s2 :
    sem_pexpr [::] s1 e >>= to_pointer = ok i ->
    write_lval [::] x (Vword (i + wrepr _ ofs)) s1 = ok s2 ->
    sem_i P' w s1 (lea_ptr x e ofs) s2.
  Proof.
    move=> he hx.
    constructor.
    rewrite /sem_sopn /= P'_globs /sem_sop2 /=.
    move: he; t_xrbindP=> _ -> /= -> /=.
    by rewrite !zero_extend_u hx.
  Qed.

  Lemma mov_ptrP s1 e i x w s2 :
    sem_pexpr [::] s1 e >>= to_pointer = ok i ->
    write_lval [::] x (Vword i) s1 = ok s2 ->
    sem_i P' w s1 (mov_ptr x e) s2.
  Proof.
    move=> he hx.
    constructor.
    rewrite /sem_sopn P'_globs /= /exec_sopn /=.
    move: he; t_xrbindP=> _ -> /= -> /=.
    by rewrite hx.
  Qed.

End X86_PROOF.

Lemma x86_mov_ofsP P' s1 e i x ofs w vpk s2 :
  P'.(p_globs) = [::] ->
  sem_pexpr [::] s1 e >>= to_pointer = ok i ->
  write_lval [::] x (Vword (i + wrepr _ ofs)) s1 = ok s2 ->
  sem_i P' w s1 (x86_mov_ofs x vpk e ofs) s2.
Proof.
  move=> P'_globs.
  rewrite /x86_mov_ofs.
  case: (mk_mov vpk).
  + by apply lea_ptrP.
  case: eqP => [->|_].
  + rewrite wrepr0 GRing.addr0.
    by apply mov_ptrP.
  by apply lea_ptrP.
Qed.


Definition x86_alloc_progP := alloc_progP x86_mov_ofsP.
