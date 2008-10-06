{- |
Module      :  $Header$
Description :  Code out overloading and qualify all names
Copyright   :  (c) Christian Maeder, DFKI GmbH 2008
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  Christian.Maeder@dfki.de
Stability   :  provisional
Portability :  portable

Code out overloading and qualify all names
-}

module CASL.Qualify (qualifySig, inverseMorphism) where

import CASL.AS_Basic_CASL
import CASL.Sign
import CASL.Morphism
import CASL.Monoton

import qualified Common.Lib.Rel as Rel
import Common.AS_Annotation
import Common.Id
import Common.LibName
import Common.Result

import Control.Monad
import Data.Maybe
import qualified Data.Map as Map
import qualified Data.Set as Set

mkOverloadedId :: Int -> Id -> Id
mkOverloadedId n i =
  Id [genToken "Over"] (i : map (stringToId  . (: [])) (show n)) $ posOfId i

mkOrReuseQualSortName :: Sort_map -> SIMPLE_ID -> LIB_ID -> Id -> Id
mkOrReuseQualSortName sm nodeId libId i =
  case Map.lookup i sm of
    Just j | isQualName j -> j
    _ -> mkQualName nodeId libId i

qualifySig :: SIMPLE_ID -> LIB_ID -> [Morphism f e ()] -> Sign f e
           -> Result (Morphism f e (), [Named (FORMULA f)])
qualifySig nodeId libId inns sig = do
  let invms = mapMaybe (maybeResult . inverseMorphism return) inns
  m <- foldM (morphismUnionM (const id) (const return))
       (embedMorphism () sig sig) invms
  let ps = predMap sig
      os = opMap sig
      ss = sortSet sig
      sm = Set.fold (\ s -> Map.insert s
                    $ mkOrReuseQualSortName (sort_map m) nodeId libId s)
           Map.empty ss
      om = createFunMap $ qualOverloaded (Map.map fst $ fun_map m)
           nodeId libId (mapOpType sm) os
      pm = Map.map fst
           $ qualOverloaded (pred_map m) nodeId libId (mapPredType sm) ps
      tar = sig
        { sortSet = Set.map (mapSort sm) ss
        , sortRel = Rel.map (mapSort sm) $ sortRel sig
        , emptySortSet = Set.map (mapSort sm) $ emptySortSet sig
        , opMap = inducedOpMap sm om os
        , assocOps = inducedOpMap sm om $ assocOps sig
        , predMap = inducedPredMap sm pm ps }
  return ((embedMorphism () sig tar)
    { sort_map = sm
    , fun_map = om
    , pred_map = pm }, monotonicities sig)

qualOverloaded :: Ord a => Map.Map (Id, a) Id -> SIMPLE_ID -> LIB_ID
               -> (a -> a) -> Map.Map Id (Set.Set a) -> Map.Map (Id, a) (Id, a)
qualOverloaded rn nodeId libId f =
  Map.foldWithKey (\ i s m -> case Set.toList s of
      [] -> error "CASL.Qualify.qualOverloaded"
      t : r -> let
        nt = f t
        m1 = Map.insert (i, nt) (case Map.lookup (i, nt) rn of
                          Just j | isQualName j -> j
                          _ -> mkQualName nodeId libId i, nt) m
       in foldr (\ (e, n) -> let ne = f e in Map.insert (i, ne)
                 (case Map.lookup (i, ne) rn of
                    Just j | isQualName j -> j
                    _ -> mkQualName nodeId libId $ mkOverloadedId n i, ne)) m1
           $ zip r [2 ..]) Map.empty

createFunMap :: Map.Map (Id, OpType) (Id, OpType)
             -> Map.Map (Id, OpType) (Id, FunKind)
createFunMap = Map.map (\ (i, t) -> (i, opKind t))

inverseMorphism :: (m -> Result m) -> Morphism f e m -> Result (Morphism f e m)
inverseMorphism invExt m = do
  iExt <- invExt $ extended_map m
  let src = msource m
      tar = mtarget m
      sm = sort_map m
      im = Map.fromList $ map (\ (s1, s2) -> (s2, s1)) $ Map.toList sm
  unless (sortSet tar == Set.map (mapSort sm) (sortSet src))
    $ fail "no injective CASL sort mapping"
  unless (opMap tar == inducedOpMap sm (fun_map m) (opMap src))
    $ fail "no injective CASL op mapping"
  unless (predMap tar == inducedPredMap sm (pred_map m) (predMap src))
    $ fail "no injective CASL pred mapping"
  return (embedMorphism iExt tar src)
    { sort_map = im
    , fun_map = Map.fromList $ map (\ ((i, t), (j, k)) ->
                  ((j, makeTotal k $ mapOpType im t), (i, opKind t)))
               $ Map.toList $ fun_map m
    , pred_map = Map.fromList $ map (\ ((i, t), j) ->
                  ((j, mapPredType im t), i)) $ Map.toList $ pred_map m
    , morKind = if morKind m == IdMor then IdMor else OtherMor }
