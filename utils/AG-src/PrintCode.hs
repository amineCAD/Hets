-- do not edit; automatically generated by UU_AG
module PrintCode where

import UU_Pretty
import UU_Pretty_ext
import Code

import UU_Pretty

type PP_Docs = [PP_Doc]
-- DataAlt -----------------------------------------------------
{-
   inherited attributes:

   chained attributes:

   synthesised attributes:
      pp                   : PP_Doc

-}
{-
   local variables for DataAlt.DataAlt:

-}
-- semantic domain
type T_DataAlt = ((PP_Doc))
-- cata
sem_DataAlt :: (DataAlt) ->
               (T_DataAlt)
sem_DataAlt ((DataAlt (_name) (_args))) =
    (sem_DataAlt_DataAlt (_name) (_args))
sem_DataAlt_DataAlt :: (String) ->
                       ([String]) ->
                       (T_DataAlt)
sem_DataAlt_DataAlt (_name) (_args) =
    let 
    in  (_name >#< hv_sp (map (pp_parens.text) _args))
-- DataAlts ----------------------------------------------------
{-
   inherited attributes:

   chained attributes:

   synthesised attributes:
      pps                  : [PP_Doc]

-}
{-
   local variables for DataAlts.Cons:

-}
{-
   local variables for DataAlts.Nil:

-}
-- semantic domain
type T_DataAlts = (([PP_Doc]))
-- cata
sem_DataAlts :: (DataAlts) ->
                (T_DataAlts)
sem_DataAlts (list) =
    (foldr (sem_DataAlts_Cons) (sem_DataAlts_Nil) ((map sem_DataAlt list)))
sem_DataAlts_Cons :: (T_DataAlt) ->
                     (T_DataAlts) ->
                     (T_DataAlts)
sem_DataAlts_Cons (_hd) (_tl) =
    let ( _hd_pp) =
            (_hd )
        ( _tl_pps) =
            (_tl )
    in  (_hd_pp : _tl_pps)
sem_DataAlts_Nil :: (T_DataAlts)
sem_DataAlts_Nil  =
    let 
    in  ([])
-- Decl --------------------------------------------------------
{-
   inherited attributes:

   chained attributes:

   synthesised attributes:
      pp                   : PP_Doc

-}
{-
   local variables for Decl.Comment:

-}
{-
   local variables for Decl.Data:

-}
{-
   local variables for Decl.Decl:

-}
{-
   local variables for Decl.TSig:

-}
{-
   local variables for Decl.Type:

-}
-- semantic domain
type T_Decl = ((PP_Doc))
-- cata
sem_Decl :: (Decl) ->
            (T_Decl)
sem_Decl ((Comment (_txt))) =
    (sem_Decl_Comment (_txt))
sem_Decl ((Data (_name) (_alts))) =
    (sem_Decl_Data (_name) ((sem_DataAlts (_alts))))
sem_Decl ((Decl (_lhs) (_rhs))) =
    (sem_Decl_Decl ((sem_Lhs (_lhs))) ((sem_Expr (_rhs))))
sem_Decl ((TSig (_name) (_tp))) =
    (sem_Decl_TSig (_name) ((sem_Type (_tp))))
sem_Decl ((Type (_name) (_tp))) =
    (sem_Decl_Type (_name) ((sem_Type (_tp))))
sem_Decl_Comment :: (String) ->
                    (T_Decl)
sem_Decl_Comment (_txt) =
    let 
    in  (if '\n' `elem` _txt
           then "{-" >-< vlist (lines _txt) >-< "-}"
           else "--" >#< _txt
        )
sem_Decl_Data :: (String) ->
                 (T_DataAlts) ->
                 (T_Decl)
sem_Decl_Data (_name) (_alts) =
    let ( _alts_pps) =
            (_alts )
    in  ("data" >#< _name
                 >|< case _alts_pps of
                      [] -> empty
                      (x:xs) ->              " =" >#<  x
                             >-< vlist (map (" |" >#<) xs)
        )
sem_Decl_Decl :: (T_Lhs) ->
                 (T_Expr) ->
                 (T_Decl)
sem_Decl_Decl (_lhs) (_rhs) =
    let ( _lhs_pp) =
            (_lhs )
        ( _rhs_pp) =
            (_rhs )
    in  (_lhs_pp >#< "="
         >-< indent 4 _rhs_pp
        )
sem_Decl_TSig :: (String) ->
                 (T_Type) ->
                 (T_Decl)
sem_Decl_TSig (_name) (_tp) =
    let ( _tp_pp,_tp_prec) =
            (_tp )
    in  (_name >#< "::" >#< _tp_pp)
sem_Decl_Type :: (String) ->
                 (T_Type) ->
                 (T_Decl)
sem_Decl_Type (_name) (_tp) =
    let ( _tp_pp,_tp_prec) =
            (_tp )
    in  ("type" >#< _name >#< "=" >#< _tp_pp)
-- Decls -------------------------------------------------------
{-
   inherited attributes:

   chained attributes:

   synthesised attributes:
      pps                  : [PP_Doc]

-}
{-
   local variables for Decls.Cons:

-}
{-
   local variables for Decls.Nil:

-}
-- semantic domain
type T_Decls = (([PP_Doc]))
-- cata
sem_Decls :: (Decls) ->
             (T_Decls)
sem_Decls (list) =
    (foldr (sem_Decls_Cons) (sem_Decls_Nil) ((map sem_Decl list)))
sem_Decls_Cons :: (T_Decl) ->
                  (T_Decls) ->
                  (T_Decls)
sem_Decls_Cons (_hd) (_tl) =
    let ( _hd_pp) =
            (_hd )
        ( _tl_pps) =
            (_tl )
    in  (_hd_pp : _tl_pps)
sem_Decls_Nil :: (T_Decls)
sem_Decls_Nil  =
    let 
    in  ([])
-- Expr --------------------------------------------------------
{-
   inherited attributes:

   chained attributes:

   synthesised attributes:
      pp                   : PP_Doc

-}
{-
   local variables for Expr.App:

-}
{-
   local variables for Expr.Let:

-}
{-
   local variables for Expr.PP:

-}
{-
   local variables for Expr.SimpleExpr:

-}
{-
   local variables for Expr.TupleExpr:

-}
-- semantic domain
type T_Expr = ((PP_Doc))
-- cata
sem_Expr :: (Expr) ->
            (T_Expr)
sem_Expr ((App (_name) (_args))) =
    (sem_Expr_App (_name) ((sem_Exprs (_args))))
sem_Expr ((Let (_decls) (_body))) =
    (sem_Expr_Let ((sem_Decls (_decls))) ((sem_Expr (_body))))
sem_Expr ((PP (_pp))) =
    (sem_Expr_PP (_pp))
sem_Expr ((SimpleExpr (_txt))) =
    (sem_Expr_SimpleExpr (_txt))
sem_Expr ((TupleExpr (_exprs))) =
    (sem_Expr_TupleExpr ((sem_Exprs (_exprs))))
sem_Expr_App :: (String) ->
                (T_Exprs) ->
                (T_Expr)
sem_Expr_App (_name) (_args) =
    let ( _args_pps) =
            (_args )
    in  (pp_parens $ _name >#< hv_sp (map pp_parens _args_pps))
sem_Expr_Let :: (T_Decls) ->
                (T_Expr) ->
                (T_Expr)
sem_Expr_Let (_decls) (_body) =
    let ( _decls_pps) =
            (_decls )
        ( _body_pp) =
            (_body )
    in  ((    "let" >#< (vlist _decls_pps)
          >-< "in " >#< _body_pp
         )
        )
sem_Expr_PP :: (PP_Doc) ->
               (T_Expr)
sem_Expr_PP (_pp) =
    let 
    in  (_pp)
sem_Expr_SimpleExpr :: (String) ->
                       (T_Expr)
sem_Expr_SimpleExpr (_txt) =
    let 
    in  (text _txt)
sem_Expr_TupleExpr :: (T_Exprs) ->
                      (T_Expr)
sem_Expr_TupleExpr (_exprs) =
    let ( _exprs_pps) =
            (_exprs )
    in  (pp_block "(" ")" "," _exprs_pps)
-- Exprs -------------------------------------------------------
{-
   inherited attributes:

   chained attributes:

   synthesised attributes:
      pps                  : [PP_Doc]

-}
{-
   local variables for Exprs.Cons:

-}
{-
   local variables for Exprs.Nil:

-}
-- semantic domain
type T_Exprs = (([PP_Doc]))
-- cata
sem_Exprs :: (Exprs) ->
             (T_Exprs)
sem_Exprs (list) =
    (foldr (sem_Exprs_Cons) (sem_Exprs_Nil) ((map sem_Expr list)))
sem_Exprs_Cons :: (T_Expr) ->
                  (T_Exprs) ->
                  (T_Exprs)
sem_Exprs_Cons (_hd) (_tl) =
    let ( _hd_pp) =
            (_hd )
        ( _tl_pps) =
            (_tl )
    in  (_hd_pp : _tl_pps)
sem_Exprs_Nil :: (T_Exprs)
sem_Exprs_Nil  =
    let 
    in  ([])
-- Lhs ---------------------------------------------------------
{-
   inherited attributes:

   chained attributes:

   synthesised attributes:
      pp                   : PP_Doc

-}
{-
   local variables for Lhs.Fun:

-}
{-
   local variables for Lhs.Pattern:

-}
{-
   local variables for Lhs.TupleLhs:

-}
-- semantic domain
type T_Lhs = ((PP_Doc))
-- cata
sem_Lhs :: (Lhs) ->
           (T_Lhs)
sem_Lhs ((Fun (_name) (_args))) =
    (sem_Lhs_Fun (_name) ((sem_Exprs (_args))))
sem_Lhs ((Pattern (_pat))) =
    (sem_Lhs_Pattern (_pat))
sem_Lhs ((TupleLhs (_comps))) =
    (sem_Lhs_TupleLhs (_comps))
sem_Lhs_Fun :: (String) ->
               (T_Exprs) ->
               (T_Lhs)
sem_Lhs_Fun (_name) (_args) =
    let ( _args_pps) =
            (_args )
    in  (_name >#< hv_sp (map pp_parens _args_pps))
sem_Lhs_Pattern :: (PP_Doc) ->
                   (T_Lhs)
sem_Lhs_Pattern (_pat) =
    let 
    in  (pp_parens _pat)
sem_Lhs_TupleLhs :: ([String]) ->
                    (T_Lhs)
sem_Lhs_TupleLhs (_comps) =
    let 
    in  (("(" >|< pp_block " " ")" "," (map text _comps)))
-- Program -----------------------------------------------------
{-
   inherited attributes:
      width                : Int

   chained attributes:

   synthesised attributes:
      output               : String

-}
{-
   local variables for Program.Program:

-}
-- semantic domain
type T_Program = (Int) ->
                 ((String))
-- cata
sem_Program :: (Program) ->
               (T_Program)
sem_Program ((Program (_decls))) =
    (sem_Program_Program ((sem_Decls (_decls))))
sem_Program_Program :: (T_Decls) ->
                       (T_Program)
sem_Program_Program (_decls) (_lhs_width) =
    let ( _decls_pps) =
            (_decls )
    in  (foldr (\x y -> x . ('\n':) . y) id
         (map (\d -> disp d _lhs_width)  _decls_pps)
         ""
        )
-- Type --------------------------------------------------------
{-
   inherited attributes:

   chained attributes:

   synthesised attributes:
      pp                   : PP_Doc
      prec                 : Int

-}
{-
   local variables for Type.Arr:
      r
      l

-}
{-
   local variables for Type.List:

-}
{-
   local variables for Type.SimpleType:

-}
{-
   local variables for Type.TupleType:

-}
-- semantic domain
type T_Type = ((PP_Doc),(Int))
-- cata
sem_Type :: (Type) ->
            (T_Type)
sem_Type ((Arr (_left) (_right))) =
    (sem_Type_Arr ((sem_Type (_left))) ((sem_Type (_right))))
sem_Type ((List (_tp))) =
    (sem_Type_List ((sem_Type (_tp))))
sem_Type ((SimpleType (_txt))) =
    (sem_Type_SimpleType (_txt))
sem_Type ((TupleType (_tps))) =
    (sem_Type_TupleType ((sem_Types (_tps))))
sem_Type_Arr :: (T_Type) ->
                (T_Type) ->
                (T_Type)
sem_Type_Arr (_left) (_right) =
    let (_l) =
            if _left_prec  <= 2 then pp_parens _left_pp  else _left_pp
        (_r) =
            if _right_prec <  2 then pp_parens _right_pp else _right_pp
        ( _left_pp,_left_prec) =
            (_left )
        ( _right_pp,_right_prec) =
            (_right )
    in  (_l     >#< "->" >-< _r,2)
sem_Type_List :: (T_Type) ->
                 (T_Type)
sem_Type_List (_tp) =
    let ( _tp_pp,_tp_prec) =
            (_tp )
    in  ("[" >|< _tp_pp >|< "]",5)
sem_Type_SimpleType :: (String) ->
                       (T_Type)
sem_Type_SimpleType (_txt) =
    let 
    in  (pp_parens $ text _txt,5)
sem_Type_TupleType :: (T_Types) ->
                      (T_Type)
sem_Type_TupleType (_tps) =
    let ( _tps_pps) =
            (_tps )
    in  (pp_block "(" ")" "," _tps_pps,5)
-- Types -------------------------------------------------------
{-
   inherited attributes:

   chained attributes:

   synthesised attributes:
      pps                  : [PP_Doc]

-}
{-
   local variables for Types.Cons:

-}
{-
   local variables for Types.Nil:

-}
-- semantic domain
type T_Types = (([PP_Doc]))
-- cata
sem_Types :: (Types) ->
             (T_Types)
sem_Types (list) =
    (foldr (sem_Types_Cons) (sem_Types_Nil) ((map sem_Type list)))
sem_Types_Cons :: (T_Type) ->
                  (T_Types) ->
                  (T_Types)
sem_Types_Cons (_hd) (_tl) =
    let ( _hd_pp,_hd_prec) =
            (_hd )
        ( _tl_pps) =
            (_tl )
    in  (_hd_pp : _tl_pps)
sem_Types_Nil :: (T_Types)
sem_Types_Nil  =
    let 
    in  ([])

