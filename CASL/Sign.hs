{- |
Module      :  $Header$
Copyright   :  (c) Christian Maeder and Uni Bremen 2002-2006
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  maeder@tzi.de
Stability   :  provisional
Portability :  portable

This module provides CASL signatures that also serve as local
  environments for the basic static analysis.
-}

module CASL.Sign where

import CASL.AS_Basic_CASL
import qualified Common.Lib.Map as Map
import qualified Common.Lib.Set as Set
import qualified Common.Lib.Rel as Rel
import qualified Common.Lib.State as State
import Common.PrettyPrint
import Common.Keywords
import Common.Id
import Common.Result
import Common.AS_Annotation
import Common.GlobalAnnotations
import Common.Print_AS_Annotation
import Common.Doc
import Common.DocUtils
import CASL.ToDoc

-- constants have empty argument lists
data OpType = OpType {opKind :: FunKind, opArgs :: [SORT], opRes :: SORT}
              deriving (Show, Eq, Ord)

data PredType = PredType {predArgs :: [SORT]} deriving (Show, Eq, Ord)

type OpMap = Map.Map Id (Set.Set OpType)

data Sign f e = Sign { sortSet :: Set.Set SORT
               , sortRel :: Rel.Rel SORT
               , opMap :: OpMap
               , assocOps :: OpMap
               , predMap :: Map.Map Id (Set.Set PredType)
               , varMap :: Map.Map SIMPLE_ID SORT
               , sentences :: [Named (FORMULA f)]
               , envDiags :: [Diagnosis]
               , globAnnos :: GlobalAnnos
               , extendedInfo :: e
               } deriving Show

-- better ignore assoc flags for equality
instance (Eq f, Eq e) => Eq (Sign f e) where
    e1 == e2 =
        sortSet e1 == sortSet e2 &&
        sortRel e1 == sortRel e2 &&
        opMap e1 == opMap e2 &&
        predMap e1 == predMap e2 &&
        extendedInfo e1 == extendedInfo e2

emptySign :: e -> Sign f e
emptySign e = Sign { sortSet = Set.empty
               , sortRel = Rel.empty
               , opMap = Map.empty
               , assocOps = Map.empty
               , predMap = Map.empty
               , varMap = Map.empty
               , sentences = []
               , envDiags = []
               , globAnnos = emptyGlobalAnnos
               , extendedInfo = e }

-- | proper subsorts (possibly excluding input sort)
subsortsOf :: SORT -> Sign f e -> Set.Set SORT
subsortsOf s e = Rel.predecessors (sortRel e) s

-- | proper supersorts (possibly excluding input sort)
supersortsOf :: SORT -> Sign f e -> Set.Set SORT
supersortsOf s e = Rel.succs (sortRel e) s

toOP_TYPE :: OpType -> OP_TYPE
toOP_TYPE OpType { opArgs = args, opRes = res, opKind = k } =
    Op_type k  args res nullRange

toPRED_TYPE :: PredType -> PRED_TYPE
toPRED_TYPE PredType { predArgs = args } = Pred_type args nullRange

toOpType :: OP_TYPE -> OpType
toOpType (Op_type k args r _) = OpType k args r

toPredType :: PRED_TYPE -> PredType
toPredType (Pred_type args _) = PredType args

instance PrettyPrint OpType where
  printText0 ga = toText ga . pretty

instance Pretty OpType where
  pretty = printOpType . toOP_TYPE

instance PrettyPrint PredType where
  printText0 ga = toText ga . pretty

instance Pretty PredType where
  pretty = printPredType . toPRED_TYPE

instance (PrettyPrint f, PrettyPrint e) => PrettyPrint (Sign f e) where
    printText0 ga = toText ga . printSign (fromText ga) (fromText ga)

instance (Pretty f, Pretty e) => Pretty (Sign f e) where
    pretty = printSign pretty pretty

printSign :: (f->Doc) -> (e->Doc) -> Sign f e ->Doc
printSign _ fE s = text (sortS++sS) <+>
    sepByCommas (map idDoc (Set.toList $ sortSet s)) $+$
    (if Rel.null (sortRel s) then empty
      else text (sortS++sS) <+>
       (fsep $ punctuate semi $ map printRel $ Map.toList
                       $ Rel.toMap $ Rel.transpose $ sortRel s))
    $+$ printSetMap (text opS) empty (opMap s)
    $+$ printSetMap (text predS) space (predMap s)
    $+$ fE (extendedInfo s)
    where printRel (supersort, subsorts) =
            printSetWithComma subsorts <+> text lessS <+>
               idDoc supersort

printSetMap :: (Pretty k,Pretty a,Ord a,Ord k) => Doc -> Doc
                 -> Map.Map k (Set.Set a) -> Doc
printSetMap header sepa m = vcat $ map (\ (i, t) ->
           header <+>
           pretty i <+> colon <> sepa <>
           pretty t)
           $ concatMap (\ (o, ts) ->
                          map ( \ ty -> (o, ty) ) $ Set.toList ts)
                   $ Map.toList m

-- working with Sign

diffSig :: Sign f e -> Sign f e -> Sign f e
diffSig a b =
    a { sortSet = sortSet a `Set.difference` sortSet b
      , sortRel = Rel.transClosure $ Rel.difference (sortRel a) $ sortRel b
      , opMap = opMap a `diffMapSet` opMap b
      , assocOps = assocOps a `diffMapSet` assocOps b
      , predMap = predMap a `diffMapSet` predMap b
      }
  -- transClosure needed:  {a < b < c} - {a < c; b}
  -- is not transitive!

diffMapSet :: (Ord a, Ord b) => Map.Map a (Set.Set b)
           -> Map.Map a (Set.Set b) -> Map.Map a (Set.Set b)
diffMapSet =
    Map.differenceWith ( \ s t -> let d = Set.difference s t in
                         if Set.null d then Nothing
                         else Just d )

addMapSet :: (Ord a, Ord b) => Map.Map a (Set.Set b) -> Map.Map a (Set.Set b)
          -> Map.Map a (Set.Set b)
addMapSet = Map.unionWith Set.union

addOpMapSet :: OpMap -> OpMap -> OpMap
addOpMapSet m = remPartOpsM . addMapSet m

addSig :: (e -> e -> e) -> Sign f e -> Sign f e -> Sign f e
addSig ad a b =
    a { sortSet = sortSet a `Set.union` sortSet b
      , sortRel = Rel.transClosure $ Rel.union (sortRel a) $ sortRel b
      , opMap = addOpMapSet (opMap a) $ opMap b
      , assocOps = addOpMapSet (assocOps a) $ assocOps b
      , predMap = addMapSet (predMap a) $ predMap b
      , extendedInfo = ad (extendedInfo a) $ extendedInfo b
      }

isEmptySig :: (e -> Bool) -> Sign f e -> Bool
isEmptySig ie s =
    Set.null (sortSet s) &&
    Rel.null (sortRel s) &&
    Map.null (opMap s) &&
    Map.null (predMap s) && ie (extendedInfo s)

isSubMapSet :: (Ord a, Ord b) => Map.Map a (Set.Set b) -> Map.Map a (Set.Set b)
            -> Bool
isSubMapSet = Map.isSubmapOfBy Set.isSubsetOf

isSubOpMap :: OpMap -> OpMap -> Bool
isSubOpMap a b = Map.isSubmapOfBy ( \ s t ->
               Set.fold ( \ e r -> r && (Set.member e t || case opKind e of
                         Partial -> Set.member e {opKind = Total} t
                         Total -> False)) True s) a b

isSubSig :: (e -> e -> Bool) -> Sign f e -> Sign f e -> Bool
isSubSig isSubExt a b =
  Set.isSubsetOf (sortSet a) (sortSet b)
          && Rel.isSubrelOf (sortRel a) (sortRel b)
          && isSubOpMap (opMap a) (opMap b)
          -- ignore associativity properties!
          && isSubMapSet (predMap a) (predMap b)
          && isSubExt (extendedInfo a) (extendedInfo b)

partOps :: Set.Set OpType -> [OpType]
partOps s = map ( \ t -> t { opKind = Partial } )
         $ Set.toList $ Set.filter ((==Total) . opKind) s

remPartOps :: Set.Set OpType -> Set.Set OpType
remPartOps s = foldr Set.delete s $ partOps s

remPartOpsM :: Ord a => Map.Map a (Set.Set OpType)
            -> Map.Map a (Set.Set OpType)
remPartOpsM = Map.map remPartOps

addDiags :: [Diagnosis] -> State.State (Sign f e) ()
addDiags ds =
    do e <- State.get
       State.put e { envDiags = reverse ds ++ envDiags e }

addSort :: SORT -> State.State (Sign f e) ()
addSort s =
    do e <- State.get
       let m = sortSet e
       if Set.member s m then
          addDiags [mkDiag Hint "redeclared sort" s]
          else State.put e { sortSet = Set.insert s m }

hasSort :: Sign f e -> SORT -> [Diagnosis]
hasSort e s = if Set.member s $ sortSet e then []
                else [mkDiag Error "unknown sort" s]

checkSorts :: [SORT] -> State.State (Sign f e) ()
checkSorts s =
    do e <- State.get
       addDiags $ concatMap (hasSort e) s

addSubsort :: SORT -> SORT -> State.State (Sign f e) ()
addSubsort = addSubsortOrIso True

addSubsortOrIso :: Bool -> SORT -> SORT -> State.State (Sign f e) ()
addSubsortOrIso b super sub =
    do if b then checkSorts [super, sub] else return ()
       e <- State.get
       let r = sortRel e
       State.put e { sortRel = (if b then id else
                         Rel.insert super sub) $ Rel.insert sub super r }
       let p = posOfId sub
           rel = " '" ++ showDoc sub (if b then " < "
                                         else " = ") ++ showDoc super "'"
       if super == sub then
          addDiags [mkDiag Warning
                    "void reflexive subsort" sub]
          else if b then
              if Rel.path super sub r then
                  if  Rel.path sub super r then
                  addDiags [Diag Warning
                            ("sorts are isomorphic" ++ rel) p]
                  else addDiags [Diag Warning
                                 ("added subsort cycle by" ++ rel) p]
              else if Rel.path sub super r then
                  addDiags [Diag Hint ("redeclared subsort" ++ rel) p]
              else return ()
          else if Rel.path super sub r then
                  if Rel.path sub super r then
                       addDiags [Diag Hint
                                 ("redeclared isomoprhic sorts" ++ rel) p]
                  else addDiags [Diag Warning
                                 ("subsort '" ++ showDoc super
                                  "' made isomorphic by" ++ rel)
                                 $ posOfId super]
               else if Rel.path sub super r then
                  addDiags [Diag Warning
                            ("subsort  '" ++ showDoc sub
                             "' made isomorphic by" ++ rel) p]
                  else return()

closeSubsortRel :: State.State (Sign f e) ()
closeSubsortRel=
    do e <- State.get
       State.put e { sortRel = Rel.transClosure $ sortRel e }

alsoWarning :: String -> Id -> [Diagnosis]
alsoWarning msg i = [mkDiag Warning ("also known as " ++ msg) i]

checkWithOtherMap :: String -> Map.Map Id a -> Id -> [Diagnosis]
checkWithOtherMap msg m i =
    case Map.lookup i m of
    Nothing -> []
    Just _ -> alsoWarning msg i

addVars :: VAR_DECL -> State.State (Sign f e) ()
addVars (Var_decl vs s _) = do
    checkSorts [s]
    mapM_ (addVar s) vs

addVar :: SORT -> SIMPLE_ID -> State.State (Sign f e) ()
addVar s v =
    do e <- State.get
       let m = varMap e
           i = simpleIdToId v
           ds = case Map.lookup v m of
                Just _ -> [mkDiag Hint "known variable shadowed" v]
                Nothing -> []
       State.put e { varMap = Map.insert v s m }
       addDiags $ ds ++ checkWithOtherMap "operation" (opMap e) i
                ++ checkWithOtherMap "predicate" (predMap e) i

addOpTo :: Id -> OpType -> OpMap -> OpMap
addOpTo k v m =
    let l = Map.findWithDefault Set.empty k m
        n = Map.insert k (Set.insert v l) m
    in case opKind v of
     Total -> let vp =  v { opKind = Partial } in
              if Set.member vp l then
              Map.insert k (Set.insert v $ Set.delete vp l) m
              else n
     _ -> if Set.member v { opKind = Total } l then m
          else n
