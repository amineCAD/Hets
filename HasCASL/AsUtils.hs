
{- HetCATS/HasCASL/AsUtils.hs
   $Id$
   Authors: Christian Maeder
   Year:    2003
   
   (further) auxiliary functions
-}

module AsUtils where

import As
import FiniteMap
import Id
import List(intersperse)
import Maybe
import Monad
import MonadState
import Set
import Result

anaList :: Monad m => (a -> m (Result b)) -> [a] -> m (Result [b])
anaList f l = 
    do rs <- mapM f l
       return $ 
	      let ms = map maybeResult rs
	          ds = concatMap diags rs
		  failErr = Diag FatalError "an element failed" $
			    if null ds then nullPos else diagPos $ head ds
		  in 
         if all isJust ms then Result ds (Just $ map fromJust ms) 
	 else Result 
		   (if any (FatalError == ) (map diagKind ds) then ds
		    else failErr : ds) 
		  Nothing

-- ---------------------------------------------------------------------
instance Show a => Show (Set a) where
    showsPrec _ s = showString "{" 
		. showSepList (showString ",") shows (setToList s)
		. showString "}"

-- ---------------------------------------------------------------------
kindArity :: Kind -> Int
kindArity(Kind args _ _) = 
    sum $ map prodClassArity args

prodClassArity :: ProdClass -> Int
prodClassArity (ProdClass l _) = length l

-- ---------------------------------------------------------------------
posOfTypePattern :: TypePattern -> Pos
posOfTypePattern (TypePattern t _ _) = posOfId t
posOfTypePattern (TypePatternToken t) = tokPos t
posOfTypePattern (MixfixTypePattern ts) = 
    if null ts then nullPos else posOfTypePattern $ head ts
posOfTypePattern (BracketTypePattern _ ts ps) = 
    if null ps then 
       if null ts then nullPos
       else posOfTypePattern $ head ts
    else head ps
posOfTypePattern (TypePatternArgs as) = 
    if null as then nullPos else 
       let TypeArg t _ _ _ = head as in tokPos t

-- ---------------------------------------------------------------------
showClassList :: [ClassName] -> ShowS
showClassList is = showParen (length is > 1)
		   $ showSepList ("," ++) ((++) . tokStr) is


----------------------------------------------------------------------------
-- FiniteMap stuff
-----------------------------------------------------------------------------

lookUp :: (Ord a, MonadPlus m) => FiniteMap a (m b) -> a -> (m b)
lookUp ce = lookupWithDefaultFM ce mzero

showMap :: Ord a => (a -> ShowS) -> (b -> ShowS) -> FiniteMap a b -> ShowS
showMap showA showB m =
    showSepList (showChar '\n') (\ (a, b) -> showA a . showString " -> " .
				 indent 2 (showB b))
				 (fmToList m) 

-----------------------------------------------------------------------------

indent :: Int -> ShowS -> ShowS
indent i s = showString $ concat $ 
	     intersperse ('\n' : replicate i ' ') (lines $ s "")


