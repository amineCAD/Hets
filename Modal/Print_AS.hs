{-
Module      :  $Header$
Copyright   :  (c) Wiebke Herding, C. Maeder, Uni Bremen 2004
Licence     :  All rights reserved.

Maintainer  :  hets@tzi.de
Stability   :  provisional
Portability :  portable

  printing AS_Modal ModalSign data types
-}

module Modal.Print_AS where

import Common.Id
import Common.Keywords
import qualified Common.Lib.Map as Map
import Common.Lib.Pretty
import Common.PrettyPrint
import Common.PPUtils
import CASL.Print_AS_Basic
import CASL.Sign
import Modal.AS_Modal
import Modal.ModalSign
import CASL.AS_Basic_CASL (FORMULA(..))

import Debug.Trace

instance PrettyPrint M_BASIC_ITEM where
    printText0 ga (Simple_mod_decl is fs _) = 
	ptext modalityS <+> semiAnno_text ga is
	      <> braces (semiAnno_text ga fs)
    printText0 ga (Term_mod_decl ss fs _) = 
        ptext termS <+> ptext modalityS <+> semiAnno_text ga  ss
	      <> braces (semiAnno_text ga fs)

instance PrettyPrint RIGOR where
    printText0 _ Rigid = ptext rigidS
    printText0 _ Flexible = ptext flexibleS

instance PrettyPrint M_SIG_ITEM where
    printText0 ga (Rigid_op_items r ls _) =
	hang (printText0 ga r <+> ptext opS <> pluralS_doc ls) 4 $ 
	     semiAnno_text ga ls
    printText0 ga (Rigid_pred_items r ls _) =
	hang (printText0 ga r <+> ptext predS <> pluralS_doc ls) 4 $ 
	     semiAnno_text ga ls

instance PrettyPrint M_FORMULA where
    printText0 ga (Box t f _) = 
       brackets (printText0 ga t) <> 
       condParensInnerF (printFORMULA ga) parens f -- (printText0 ga) parens f
    printText0 ga (Diamond t f _) = 
	let sp = case t of 
			 Simple_mod _ -> (<>)
			 _ -> (<+>)
	    in ptext lessS `sp` printText0 ga t `sp` ptext greaterS 
		   <+> condParensInnerF (printFORMULA ga) parens f

instance PrettyPrint MODALITY where
    printText0 ga (Simple_mod ident) = 
	if tokStr ident == emptyS then empty
	   else printText0 ga ident
    printText0 ga (Term_mod t) = printText0 ga t

instance PrettyPrint ModalSign where
    printText0 ga s = 
	let ms = modies s      
	    tms = termModies s in       -- Map Id [Annoted (FORMULA M_FORMULA)]
	printSetMap (ptext rigidS <+> ptext opS) empty ga (rigidOps s) 
	$$
	printSetMap (ptext rigidS <+> ptext predS) space ga (rigidPreds s) 
	$$ (if Map.isEmpty ms then empty else
	ptext modalitiesS <+> semiT_text ga (Map.keys ms)
            <> braces (printFormulaOfModalSign ga $ Map.elems ms))
	$$ (if Map.isEmpty tms then empty else
	ptext termS <+> ptext modalityS <+> semiT_text ga (Map.keys tms) 
            <> braces (printFormulaOfModalSign ga (Map.elems tms)))



condParensInnerF :: PrettyPrint f => (FORMULA f -> Doc)
		    -> (Doc -> Doc)    -- ^ a function that surrounds 
				       -- the given Doc with appropiate 
				       -- parens
		    -> FORMULA f -> Doc
condParensInnerF pf parens_fun f =
    case f of
    Quantification _ _ _ _ -> f'
    True_atom _            -> f'
    False_atom _           -> f'
    Predication _ _ _      -> f'
    Definedness _ _        -> f'
    Existl_equation _ _ _  -> f' 
    Strong_equation _ _ _  -> f'
    Membership _ _ _       -> f'
    _                      -> parens_fun f'
    where f' = pf f 
