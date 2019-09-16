:- module(catobj, [
    cat_co/2]).

:- use_module(slashes).
:- use_module(util, [
    subsumed_sub_term/2]).

cat_co(X0/Y0, X/Y) :-
  !,
  cat_co(X0, X),
  cat_co(Y0, Y).
cat_co(X0\Y0, X\Y) :-
  !,
  cat_co(X0, X),
  cat_co(Y0, Y).
cat_co(conj, conj(_)) :-
  !.
cat_co(B, co(B, _)).

der_coder(t(Sem, Cat, Token, Atts), t(Sem, CO, Token, Atts)) :-
  !,
  cat_co(Cat, CO).
der_coder(Der, CODer) :-
  Der =.. [Fun, Cat|Args],
  cat_co(Cat, CO),
  CODer =.. [Fun, CO|Args].

coder_bind(fa(X, _, D1, D2)) :-
  const_cat(D1, X1/Y1),
  const_cat(D2, Y2),
  cos_bind(X, X1),
  cos_bind(Y1, Y2),
  coder_bind(D1),
  coder_bind(D2).
coder_bind(ba(X, _, D2, D1)) :-
  const_cat(D1, X1\Y1),
  const_cat(D2, Y2),
  cos_bind(X, X1),
  cos_bind(Y1, Y2),
  coder_bind(D1),
  coder_bind(D2).
coder_bind(fc(X/Z, _, D1, D2)) :-
  const_cat(D1, X1/Y1),
  const_cat(D2, Y2/Z2),
  cos_bind(X, X1),
  cos_bind(Y1, Y2),
  cos_bind(Z2, Z),
  coder_bind(D1),
  coder_bind(D2).
coder_bind(bc(X\Z, _, D1, D2)) :-
  const_cat(D1, X1\Y1),
  const_cat(D2, Y2\Z2),
  cos_bind(X, X1),
  cos_bind(Y1, Y2),
  cos_bind(Z2, Z),
  coder_bind(D1),
  coder_bind(D2).
coder_bind(fxc(X/Z, _, D1, D2)) :-
  const_cat(D1, X1/Y1),
  const_cat(D2, Y2\Z2),
  cos_bind(X, X1),
  cos_bind(Y1, Y2),
  cos_bind(Z2, Z),
  coder_bind(D1),
  coder_bind(D2).
coder_bind(bxc(X\Z, _, D1, D2)) :-
  const_cat(D1, X1\Y1),
  const_cat(D2, Y2/Z2),
  cos_bind(X, X1),
  cos_bind(Y1, Y2),
  cos_bind(Z2, Z),
  coder_bind(D1),
  coder_bind(D2).
coder_bind(gfc((X/Z)/A, _, D1, D2)) :-
  const_cat(D1, X1/Y1),
  const_cat(D2, (Y2/Z2)/A2),
  cos_bind(X, X1),
  cos_bind(Y1, Y2),
  cos_bind(Z2, Z),
  cos_bind(A2, A),
  coder_bind(D1),
  coder_bind(D2).
coder_bind(gbc((X\Z)\A, _, D1, D2)) :-
  const_cat(D1, X1\Y1),
  const_cat(D2, (Y2\Z2)\A2),
  cos_bind(X, X1),
  cos_bind(Y1, Y2),
  cos_bind(Z2, Z),
  cos_bind(A2, A),
  coder_bind(D1),
  coder_bind(D2).
coder_bind(gfxc((X\Z)\A, _, D1, D2)) :-
  const_cat(D1, X1/Y1),
  const_cat(D2, (Y2\Z2)\A2),
  cos_bind(X, X1),
  cos_bind(Y1, Y2),
  cos_bind(Z2, Z),
  cos_bind(A2, A),
  coder_bind(D1),
  coder_bind(D2).
coder_bind(gbxc((X/Z)/A, _, D1, D2)) :-
  const_cat(D1, X1\Y1),
  const_cat(D2, (Y2/Z2)/A2),
  cos_bind(X, X1),
  cos_bind(Y1, Y2),
  cos_bind(Z2, Z),
  cos_bind(A2, A),
  coder_bind(D1),
  coder_bind(D2).
coder_bind(ftr(A/(B\C), _, D1)) :-
  const_cat(D1, B1),
  cos_bind(A, C),
  cos_bind(B, B1),
  coder_bind(D1).
coder_bind(btr(A\(B/C), _, D1)) :-
  const_cat(D1, B1),
  cos_bind(A, C),
  cos_bind(B, B1),
  coder_bind(D1).
coder_bind(conj(conj(Y), _, D1, D2)) :-
  const_cat(D1, Y),
  coder_bind(D1),
  coder_bind(D2).
coder_bind(t(_, _, _, _)).

cos_bind(X1/Y1, X2/Y2) :-
  cos_bind(X1, X2),
  cos_bind(Y1, Y2).
cos_bind(X1\Y1, X2\Y2) :-
  cos_bind(X1, X2),
  cos_bind(Y1, Y2).
cos_bind(co(_, I), co(_, I)).

cos_bound(X1/Y1, X2/Y2) :-
  cos_bound(X1, X2),
  cos_bound(Y1, Y2).
cos_bound(X1\Y1, X2\Y2) :-
  cos_bound(X1, X2),
  cos_bound(Y1, Y2).
cos_bound(co(_, I), co(_, J)) :-
  I == J.

const_cat(t(_, Cat, _, _), Cat) :-
  !.
const_cat(Const, Cat) :-
  arg(1, Const, Cat).

co_references(_/B, C) :-
  cos_bound(B, C).
co_references(_\B, C) :-
  cos_bound(B, C).
co_references(A, B/_) :-
  co_references(A, B).
co_references(A, B\_) :-
  co_references(A, B).

der_deps(Der, Deps) :-
  der_coder(Der, CODer),
  coder_bind(CODer),
  findall(t(Sem, CO, Token, Atts),
      ( subsumed_sub_term(t(Sem, CO, Token, Atts), CODer)
      ), Tokens),
  findall(F-A,
      ( member(F, Tokens),
        member(A, Tokens),
        F = t(_, FCO, _, _),
        A = t(_, ACO, _, _),
        co_references(FCO, ACO)
      ), Edges),
  raise(not_implemented).
  % TODO:
  % For each ArgCO that occurs, find out which token is its head. (At the same
  % time, compute dependencies involving its own ArgCOs - implying that somehow
  % we should process ArgCOs in topological order, starting with the basic
  % ones.)
