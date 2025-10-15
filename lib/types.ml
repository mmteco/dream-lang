open Ast

type ty =
  | TyInt
  | TyFloat
  | TyString
  | TyBool
  | TyNone
  | TyVar of string
  | TyList of ty
  | TyDict of ty * ty
  | TyTuple of ty list
  | TyFunc of ty list * ty
  | TyUnion of ty list
  | TyGeneric of string * ty
  | TyOption of ty
  | TyResult of ty * ty
  | TyEnum of string * ty list
  | TyUnknown

let rec type_expr_to_ty = function
  | TInt -> TyInt
  | TFloat -> TyFloat
  | TString -> TyString
  | TBool -> TyBool
  | TNone -> TyNone
  | TVar name -> TyVar name
  | TList t -> TyList (type_expr_to_ty t)
  | TDict (k, v) -> TyDict (type_expr_to_ty k, type_expr_to_ty v)
  | TTuple ts -> TyTuple (List.map type_expr_to_ty ts)
  | TFunc (params, ret) -> TyFunc (List.map type_expr_to_ty params, type_expr_to_ty ret)
  | TUnion ts -> TyUnion (List.map type_expr_to_ty ts)
  | TGeneric (name, t) -> TyGeneric (name, type_expr_to_ty t)
  | TOption t -> TyOption (type_expr_to_ty t)
  | TResult (ok, err) -> TyResult (type_expr_to_ty ok, type_expr_to_ty err)
  | TEnum (name, params) -> TyEnum (name, List.map type_expr_to_ty params)

let rec ty_to_string = function
  | TyInt -> "int"
  | TyFloat -> "float"
  | TyString -> "string"
  | TyBool -> "bool"
  | TyNone -> "None"
  | TyVar name -> name
  | TyList t -> Printf.sprintf "list[%s]" (ty_to_string t)
  | TyDict (k, v) -> Printf.sprintf "dict[%s, %s]" (ty_to_string k) (ty_to_string v)
  | TyTuple ts -> Printf.sprintf "(%s)" (String.concat ", " (List.map ty_to_string ts))
  | TyFunc (params, ret) ->
      Printf.sprintf "(%s) -> %s"
        (String.concat ", " (List.map ty_to_string params))
        (ty_to_string ret)
  | TyUnion ts -> String.concat " | " (List.map ty_to_string ts)
  | TyGeneric (name, t) -> Printf.sprintf "%s[%s]" name (ty_to_string t)
  | TyOption t -> Printf.sprintf "Option[%s]" (ty_to_string t)
  | TyResult (ok, err) -> Printf.sprintf "Result[%s, %s]" (ty_to_string ok) (ty_to_string err)
  | TyEnum (name, []) -> name
  | TyEnum (name, params) -> Printf.sprintf "%s[%s]" name (String.concat ", " (List.map ty_to_string params))
  | TyUnknown -> "?"

let rec occurs name = function
  | TyVar v -> v = name
  | TyList t -> occurs name t
  | TyDict (k, v) -> occurs name k || occurs name v
  | TyTuple ts -> List.exists (occurs name) ts
  | TyFunc (params, ret) -> List.exists (occurs name) params || occurs name ret
  | TyUnion ts -> List.exists (occurs name) ts
  | TyGeneric (_, t) -> occurs name t
  | TyOption t -> occurs name t
  | TyResult (ok, err) -> occurs name ok || occurs name err
  | _ -> false

module Subst = Map.Make(String)

type substitution = ty Subst.t

let empty_subst = Subst.empty

let rec apply_subst subst = function
  | TyVar name ->
      (try Subst.find name subst with Not_found -> TyVar name)
  | TyList t -> TyList (apply_subst subst t)
  | TyDict (k, v) -> TyDict (apply_subst subst k, apply_subst subst v)
  | TyTuple ts -> TyTuple (List.map (apply_subst subst) ts)
  | TyFunc (params, ret) ->
      TyFunc (List.map (apply_subst subst) params, apply_subst subst ret)
  | TyUnion ts -> TyUnion (List.map (apply_subst subst) ts)
  | TyGeneric (name, t) -> TyGeneric (name, apply_subst subst t)
  | TyOption t -> TyOption (apply_subst subst t)
  | TyResult (ok, err) -> TyResult (apply_subst subst ok, apply_subst subst err)
  | t -> t

let compose_subst s1 s2 =
  Subst.union (fun _ v1 _ -> Some v1) (Subst.map (apply_subst s1) s2) s1

let rec unify t1 t2 =
  match (t1, t2) with
  | (TyInt, TyInt) | (TyFloat, TyFloat) | (TyString, TyString)
  | (TyBool, TyBool) | (TyNone, TyNone) -> empty_subst
  | (TyVar name, t) | (t, TyVar name) ->
      if occurs name t then
        failwith (Printf.sprintf "Occurs check failed: %s in %s" name (ty_to_string t))
      else
        Subst.singleton name t
  | (TyList t1, TyList t2) -> unify t1 t2
  | (TyOption t1, TyOption t2) -> unify t1 t2
  | (TyResult (ok1, err1), TyResult (ok2, err2)) ->
      let s1 = unify ok1 ok2 in
      let s2 = unify (apply_subst s1 err1) (apply_subst s1 err2) in
      compose_subst s2 s1
  | (TyDict (k1, v1), TyDict (k2, v2)) ->
      let s1 = unify k1 k2 in
      let s2 = unify (apply_subst s1 v1) (apply_subst s1 v2) in
      compose_subst s2 s1
  | (TyTuple ts1, TyTuple ts2) when List.length ts1 = List.length ts2 ->
      List.fold_left2
        (fun subst t1 t2 ->
          let s = unify (apply_subst subst t1) (apply_subst subst t2) in
          compose_subst s subst)
        empty_subst ts1 ts2
  | (TyFunc (p1, r1), TyFunc (p2, r2)) when List.length p1 = List.length p2 ->
      let param_subst = List.fold_left2
        (fun subst t1 t2 ->
          let s = unify (apply_subst subst t1) (apply_subst subst t2) in
          compose_subst s subst)
        empty_subst p1 p2
      in
      let ret_subst = unify (apply_subst param_subst r1) (apply_subst param_subst r2) in
      compose_subst ret_subst param_subst
  | (TyUnion ts1, TyUnion ts2) when List.length ts1 = List.length ts2 ->
      List.fold_left2
        (fun subst t1 t2 ->
          let s = unify (apply_subst subst t1) (apply_subst subst t2) in
          compose_subst s subst)
        empty_subst ts1 ts2
  | _ ->
      failwith (Printf.sprintf "Cannot unify %s and %s" (ty_to_string t1) (ty_to_string t2))

let is_compatible t1 t2 =
  try
    let _ = unify t1 t2 in
    true
  with _ -> false
