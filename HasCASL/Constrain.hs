
{- |
Module      :  $Header$
Copyright   :  (c) Christian Maeder and Uni Bremen 2003 
Licence     :  similar to LGPL, see HetCATS/LICENCE.txt or LIZENZ.txt

Maintainer  :  maeder@tzi.de
Stability   :  experimental
Portability :  portable 

constraint resolution

-}

module HasCASL.Constrain where

import HasCASL.Unify 
import HasCASL.As
import HasCASL.AsUtils
import HasCASL.PrintAs
import HasCASL.Le
import HasCASL.TypeAna
import qualified Common.Lib.Set as Set
import Common.PrettyPrint
import Common.Lib.Pretty
import Common.Keywords
import Common.Id

import Data.List
import Data.Maybe

data Constrain = Kinding Type Kind
               | Subtyping Type Type 
		 deriving (Eq, Ord, Show)

instance PrettyPrint Constrain where
    printText0 ga c = case c of 
       Kinding ty k -> printText0 ga ty <+> colon 
				      <+> printText0 ga k
       Subtyping t1 t2 -> printText0 ga t1 <+> text lessS
				      <+> printText0 ga t2

instance PosItem Constrain where
  get_pos c = Just $ case c of 
    Kinding ty _ -> posOfType ty
    Subtyping t1 t2 -> firstPos [t1, t2] []

type Constraints = Set.Set Constrain

noC :: Constraints
noC = Set.empty

joinC :: Constraints -> Constraints -> Constraints
joinC = Set.union

substC :: Subst -> Constraints -> Constraints
substC s = Set.image (\ c -> case c of
    Kinding ty k -> Kinding (subst s ty) k
    Subtyping t1 t2 -> Subtyping (subst s t1) $ subst s t2)

inHnf :: Type -> Bool
inHnf ty = 
    case ty of 
        TypeName _ _ n -> n /= 0
	TypeAppl t _ -> inHnf t
	ExpandedType _ t -> inHnf t
	_ -> False

toHnf :: Monad m => Env -> Constrain -> m Constraints
toHnf e c = case c of
    Kinding ty _ -> if inHnf ty then return $ Set.single c
		    else do cs <- byInst c 
			    pss <- mapM (toHnf e) $ Set.toList cs 
			    return $ Set.unions pss
    Subtyping _ _ -> return noC -- ignore


simplify :: Constraints -> Constraints -> Constraints
simplify cs rs = 
    if Set.isEmpty rs then cs
    else let (r, rt) = Set.deleteFindMin rs in
         case entail (Set.union cs rt) r of
         Just _ -> simplify cs rt
	 Nothing -> simplify (Set.insert r cs) rt

entail :: Monad m => Constraints -> Constrain -> m ()
entail ps p = if p `Set.member` ps then return ()
       else do is <- byInst p
	       mapM_ (entail ps) $ Set.toList is

byInst :: Monad m => Constrain -> m Constraints
byInst c = case c of 
    Kinding ty k -> case ty of 
      ExpandedType _ t -> byInst $ Kinding t k
      _ -> case k of
	   Intersection l _ -> if null l then return noC else
			  do pss <- mapM (\ ik -> byInst (Kinding ty ik)) l 
			     return $ Set.unions pss
	   ExtKind ek _ _ -> byInst (Kinding ty ek)
	   ClassKind _ _ -> let (topTy, args) = getTypeAppl ty in
	       case topTy of 
	       TypeName _ kind _ -> {-if null args then
		   if kind == k && n == 0 then return noC 
		         else return $ Set.single (Kinding topTy k)
		   else -} do 
		       let ks = getKindAppl kind args
		       newKs <- dom k ks 
		       return $ Set.fromList $ zipWith Kinding args newKs
	       _ -> error "byInst: unexpected Type" 
	   _ -> error "byInst: unexpected Kind" 
    _ -> return noC

maxKind :: Kind -> Kind -> Maybe Kind
maxKind k1 k2 = if lesserKind k1 k2 then Just k1 else 
		if lesserKind k2 k1 then Just k2 else Nothing

maxKinds :: [Kind] -> Maybe Kind
maxKinds l = case l of 
    [] -> Nothing
    [k] -> Just k
    [k1, k2] -> maxKind k1 k2
    k1 : k2 : ks -> case maxKind k1 k2 of 
          Just k -> maxKinds (k : ks)
	  Nothing -> do k <- maxKinds (k2 : ks)
			maxKind k1 k 

maxKindss :: [[Kind]] -> Maybe [Kind]
maxKindss l = let margs = map maxKinds $ transpose l in
   if all isJust margs then Just $ map fromJust margs
      else Nothing

dom :: Monad m => Kind -> [(Kind, [Kind])] -> m [Kind]
dom k ks = let fks = filter ( \ (rk, _) -> lesserKind rk k ) ks 
	       margs = maxKindss $ map snd fks
           in if null fks then fail "class not found" else case margs of 
	      Nothing -> fail "dom: maxKind"
	      Just args -> if any ((args ==) . snd) fks then return args
			   else fail "dom: not coregular"

getKindAppl :: Kind -> [a] -> [(Kind, [Kind])]
getKindAppl k args = if null args then [(k, [])] else
    case k of 
    FunKind k1 k2 _ -> let ks = getKindAppl k2 (tail args)
                       in map ( \ (rk, kargs) -> (rk, k1 : kargs)) ks
    Intersection l _ ->
	concatMap (flip getKindAppl args) l
    ExtKind ek _ _ -> getKindAppl ek args
    ClassKind _ ck -> getKindAppl ck args
    Downset _ _ dk _ -> getKindAppl dk args
    _ -> error ("getKindAppl " ++ show k)

getTypeAppl :: Type -> (Type, [Type])
getTypeAppl ty = let (t, args) = getTyAppl ty in
   (t, reverse args) where
    getTyAppl typ = case typ of
	TypeAppl t1 t2 -> let (t, args) = getTyAppl t1 in (t, t2 : args)
	ExpandedType _ t -> getTyAppl t
	LazyType t _ -> getTyAppl t
	KindedType t _ _ -> getTyAppl t
	ProductType ts _ -> (TypeName productId star 0, reverse ts)
	FunType t1 a t2 _ -> (TypeName (arrowId a) funKind 0, [t2, t1])
	_ -> (typ, [])
    
    
