From mathcomp Require Import all_ssreflect all_algebra.
Require Import psem x86_variables.
Import Utf8.
Import compiler_util x86_sem.
Require x86_decl.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

#[ local ] Existing Instance x86_decl.x86_pd.

(* -------------------------------------------------------------------- *)
Lemma xreg_of_varI ii x y :
  xreg_of_var ii x = ok y →
  match y with
  | Reg r => register_of_var x = Some r
  | XReg r => xmm_register_of_var x = Some r
  | _ => False
  end.
Proof.
  rewrite /xreg_of_var.
  case: xmm_register_of_var; last case: register_of_var; last by [].
  all: by move => r [<-].
Qed.

(* -------------------------------------------------------------------- *)
Lemma inj_rflag_of_var ii x y v :
     rflag_of_var ii x = ok v
  -> rflag_of_var ii y = ok v
  -> v_var x = y.
Proof.
case: x y => -[] xt xn xi [] [] yt yn yi; rewrite /rflag_of_var /=.
t_xrbindP => _ /assertP /eqP ->.
case Ex: (rflag_of_string xn) => [vx|] // -[?]; subst vx.
move=> _ /assertP /eqP ->.
case Ey: (rflag_of_string yn) => [vy|] // -[?]; subst vy.
by f_equal; apply: (inj_rflag_of_string Ex Ey).
Qed.

(* -------------------------------------------------------------------- *)
Definition of_rbool (v : rflagv) :=
  if v is Def b then Vbool b else undef_b.

(* -------------------------------------------------------------------- *)
Definition eqflags (m: estate) (rf: rflagmap) : Prop :=
  ∀ f v, get_var (evm m) (var_of_flag f) = ok v → value_uincl v (of_rbool (rf f)).

Variant disj_rip rip := 
  | Drip of
    (∀ r, var_of_register r <> rip) &
    (∀ r, var_of_xmm_register r <> rip) &
    (∀ f, var_of_flag f <> rip).

Variant lom_eqv rip (m : estate) (lom : x86_mem) :=
  | MEqv of
         emem m = asm_mem lom
    & get_var (evm m) rip = ok (Vword lom.(asm_rip)) 
    & disj_rip rip 
    & (∀ r v, get_var (evm m) (var_of_register r) = ok v → value_uincl v (Vword (asm_reg lom r)))
    & (∀ r v, get_var (evm m) (var_of_xmm_register r) = ok v → value_uincl v (Vword (asm_xreg lom r)))
    & eqflags m (asm_flag lom).

(* -------------------------------------------------------------------- *)
Definition value_of_bool (b: exec bool) : exec value :=
  match b with
  | Ok b => ok (Vbool b)
  | Error ErrAddrUndef => ok undef_b
  | Error e => Error e
  end.

(* -------------------------------------------------------------------- *)
Lemma xgetreg_ex rip x r v s xs :
  lom_eqv rip s xs →
  register_of_var x = Some r →
  get_var s.(evm) x = ok v →
  value_uincl v (Vword (xs.(asm_reg) r)).
Proof. case => _ _ _ eqv _ _ /var_of_register_of_var <-{x}; exact: eqv. Qed.

(* -------------------------------------------------------------------- *)
Lemma xxgetreg_ex rip x r v s xs :
  lom_eqv rip s xs →
  xmm_register_of_var x = Some r →
  get_var (evm s) x = ok v →
  value_uincl v (Vword (asm_xreg xs r)).
Proof. by case => _ _ _ _ eqr _ /xmm_register_of_varI ?; subst x; auto. Qed.

(* -------------------------------------------------------------------- *)
Lemma xgetflag_ex ii m rf x f v :
  eqflags m rf →
  rflag_of_var ii x = ok f →
  get_var (evm m) x = ok v →
  value_uincl v (of_rbool (rf f)).
Proof.
move: (@var_of_flag_of_var x).
move => h eqm; case: x h => -[] xt xn xi /=.
rewrite /rflag_of_var /flag_of_var /= => h.
t_xrbindP => _ /assertP /eqP ?; subst xt.
case: rflag_of_string h => //= fl /(_ _ erefl) <- [<-] /= ok_v.
apply (eqm _ _ ok_v).
Qed.

Lemma gxgetflag_ex ii m rf (x:gvar) f v :
  eqflags m rf →
  rflag_of_var ii x.(gv) = ok f →
  get_gvar [::] (evm m) x = ok v →
  value_uincl v (of_rbool (rf f)).
Proof.
  by rewrite /get_gvar; case: ifP => // ?; apply: xgetflag_ex.   
Qed.

Corollary xgetflag ii m rf x f v b :
  eqflags m rf →
  rflag_of_var ii x = ok f →
  get_var (evm m) x = ok v →
  to_bool v = ok b →
  rf f = Def b.
Proof.
move => eqm ok_f ok_v ok_b.
have := xgetflag_ex eqm ok_f ok_v.
case: {ok_v} v ok_b => //.
- by move => b' [<-]; case: (rf _) => // ? ->.
by case.
Qed.

Corollary gxgetflag ii m rf (x:gvar) f v b :
  eqflags m rf →
  rflag_of_var ii x.(gv) = ok f →
  get_gvar [::] (evm m) x = ok v →
  to_bool v = ok b →
  rf f = Def b.
Proof.
  by rewrite /get_gvar; case: ifP => // ?; apply: xgetflag. 
Qed.

(* -------------------------------------------------------------------- *)
Lemma eq_get_gvar m x y vx vy: 
  v_var (gv x) = v_var (gv y) -> get_gvar [::] m x = ok vx -> get_gvar [::] m y = ok vy -> vx = vy.
Proof.
  by rewrite /get_gvar; case:ifP => //; case: ifP => // ?? -> -> [->].
Qed.

Lemma eval_assemble_cond ii m rf e c v:
  eqflags m rf →
  assemble_cond ii e = ok c →
  sem_pexpr [::] m e = ok v →
  let get x :=
    if rf x is Def b then ok b else undef_error in
  ∃ v', value_of_bool (eval_cond get c) = ok v' ∧ value_uincl v v'.
Proof.
move=> eqv; case: e => //.
+ move => x /=; t_xrbindP => r ok_r ok_ct ok_v.
  have := gxgetflag_ex eqv ok_r ok_v.
  by case: {ok_r ok_v} r ok_ct => // -[<-] {c} /= h; eexists; split; eauto; case: (rf _).
+ do 2! case=> //; move=> x /=; t_xrbindP => r.
  move => ok_r ok_ct vx ok_vx /sem_sop1I [/= vb ok_vb -> {v}].
  have := gxgetflag eqv ok_r ok_vx ok_vb.
  by case: {ok_r ok_vx ok_vb} r ok_ct => // -[<-] {c} /= -> /=; eexists.
+ case=> //; first do 3! case=> //;move=> x.
  * case=> //; first do 2! case=> //.
    - move=> y /=; t_xrbindP => r1 ok_r1 r2 ok_r2 _ /assertP /andP [/eqP ? /eqP ? ?]; subst r1 r2 c.
      move=> resx vx ok_vx ok_resx resy vy ok_vy ok_resy ok_v.
      have /sem_sop1I [/=rxb ok_rxb resxE] := ok_resx.
      have /sem_sop1I [/=ryb ok_ryb resyE] := ok_resy.
      have := gxgetflag eqv ok_r1 ok_vx ok_rxb => CFE.
      have := gxgetflag eqv ok_r2 ok_vy ok_ryb => ZFE.
      rewrite /eval_cond; rewrite CFE ZFE /=; subst resx resy.
      by move: ok_v; rewrite /sem_sop2 /= => -[<-]; eauto.
    - move=> st [] // y; case=> // z; do 2! case=> //; case=> // t.
      move=> /=; t_xrbindP => rx ok_rx ry ok_ry rz ok_rz rt ok_rt _ /assertP /and4P [].
      do 4 move=> /eqP ?; move=> ?; subst rx ry rz rt c.
      have heq := inj_rflag_of_var ok_rz ok_rt.
      move=> vNx vx ok_vx ok_vNx res vby vy ok_vy ok_vby.
      move=> vtz vz ok_vz trz vtt vNt vt.
      move=> /(eq_get_gvar heq ok_vz) ?;subst vz.
      move=> ok_vNt trNt <-.
      have [/=vbx ok_vbx ?] := sem_sop1I ok_vNx; subst vNx.
      have [/=vbt ok_vbt ?] := sem_sop1I ok_vNt; subst vNt.
      have := gxgetflag eqv ok_rx ok_vx ok_vbx => ZFE.
      have := gxgetflag eqv ok_ry ok_vy ok_vby => SFE.
      have := gxgetflag eqv ok_rz ok_vz ok_vbt => OFE.
      rewrite /= ZFE SFE OFE /= /sem_sop2 /=.
      have [??]:= truncate_val_bool trNt; subst.
      move: trz;rewrite /truncate_val /= ok_vbt => -[?];subst.
      by rewrite eq_sym; t_xrbindP=> vres; case: (boolP vby) => hvby //= -[<-] <-;
       rewrite ?eqb_id ?eqbF_neg;eexists.
  * case: x => // x; case => // [y /=|].
    - t_xrbindP=> rx ok_rx ry ok_ry  _ /assertP /andP [] /eqP ? /eqP ? ?; subst rx ry c.
      move=> vx ok_vx vy ok_vy.
      rewrite /sem_sop2 /=; t_xrbindP => /= xb ok_bx yb ok_by <-.
      have -> /= := gxgetflag eqv ok_rx ok_vx ok_bx.
      have ->/= := gxgetflag eqv ok_ry ok_vy ok_by.
      eexists; split; reflexivity.
    - move=> st []// y []// []// []// z []//= t.
      t_xrbindP=> rx ok_rx ry ok_ry rz ok_rz rt ok_rt _ /assertP /and4P [].
      do 4 move=> /eqP ?; move=> ?; subst rx ry rz rt c.
      have heq := inj_rflag_of_var ok_rz ok_rt.
      move=> vx ok_vx ww vby vy ok_vy ok_vby trNz vNz vz ok_vz ok_vNz ok_trNz trz vt.
      move=> /(eq_get_gvar heq ok_vz) ? ok_trz ?;subst vz ww.
      rewrite /sem_sop2 /=; t_xrbindP => /= vbx ok_vbx vbres ok_vbres <- {v}.
      have [/=vbz ok_vbz ?] := sem_sop1I ok_vNz; subst vNz.
      have := gxgetflag eqv ok_rx ok_vx ok_vbx => ZFE.
      have := gxgetflag eqv ok_ry ok_vy ok_vby => SFE.
      have := gxgetflag eqv ok_rz ok_vz ok_vbz => OFE.
      rewrite /= ZFE SFE OFE /=.
      have [??]:= truncate_val_bool ok_trNz; subst.
      move: ok_trz;rewrite /truncate_val /= ok_vbz => -[?];subst.
      by rewrite eq_sym; case: (boolP vby) ok_vbres => hvby /= [<-];
       rewrite ?eqb_id ?eqbF_neg ?negbK; eexists.
+ move=> st []// x [] // => [|[] // [] //] y.
  * case=> // -[] // -[] // z /=; t_xrbindP => rx ok_rx ry ok_ry rz ok_rz _ /assertP /and3P [].
    do 3! move/eqP=> ?; move=> ?; subst rx ry rz c.
    have heq := inj_rflag_of_var ok_ry ok_rz.
    move=> vbx vx ok_vx ok_vbx ytr vy ok_vy ok_ytr.
    move=> ytr' vNy vy' /(eq_get_gvar heq ok_vy) ? ok_vNy ok_yNtr <- /=; subst vy'.
    have /sem_sop1I[/=vbz ok_vbz ?] := ok_vNy; subst vNy.
    have := gxgetflag eqv ok_rx ok_vx ok_vbx => SFE.
    have := gxgetflag eqv ok_ry ok_vy ok_vbz => OFE.
    rewrite /= SFE OFE /=.
    have [??]:= truncate_val_bool ok_yNtr; subst.
    move: ok_ytr;rewrite /truncate_val /= ok_vbz => -[?];subst.
    eexists; split; first by eauto.
    by rewrite eq_sym;case vbx => /=; rewrite ?eqb_id ?eqbF_neg.
  * case=> // z /=; t_xrbindP => vx ok_x vy ok_y vz ok_z _ /assertP /and3P [].
    do 3! move/eqP=> ?; subst vx vy vz => <-.
    have heq := inj_rflag_of_var ok_y ok_z.
    move=> vbx vx ok_vx ok_vbx ytr vNy vy ok_vy ok_vNy ok_ytr.
    move=> yNtr vy' /(eq_get_gvar heq ok_vy) ? ok_yNtr ?;subst vy' v.
    have /sem_sop1I[/=vby ok_vby ?] := ok_vNy; subst vNy.
    have := gxgetflag eqv ok_x ok_vx ok_vbx => SFE.
    have := gxgetflag eqv ok_y ok_vy ok_vby => OFE.
    rewrite /= SFE {SFE} /= OFE {OFE} /=; eexists; split; first by eauto.
    have [??]:= truncate_val_bool ok_ytr; subst.
    move: ok_yNtr;rewrite /truncate_val /= ok_vby => -[?];subst.
    by rewrite eq_sym;case vbx => /=; rewrite ?eqb_id ?eqbF_neg ?negbK.
Qed.

(* -------------------------------------------------------------------- *)
Lemma xscale_ok ii z sc :
  scale_of_z' ii z = ok sc ->
  z = word_of_scale sc.
Proof.
  rewrite /scale_of_z' -[X in _ -> X = _]wrepr_unsigned.
  case: (wunsigned z) => //.
  do! (case=> //; try by move=> <-).
Qed.
