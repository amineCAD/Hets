{- |
Module      :  ./OWL2/ManchesterPrint.hs
Copyright   :  (c) Felix Gabriel Mance
License     :  GPLv2 or higher, see LICENSE.txt

Maintainer  :  f.mance@jacobs-university.de
Stability   :  provisional
Portability :  portable

Pretty printing for the Manchester Syntax of OWL 2
-}

module OWL2.ManchesterPrint where

import Common.Doc
import Common.DocUtils
import Common.AS_Annotation as Anno
import Common.Lib.State

import OWL2.AS
import OWL2.Extract
import OWL2.MS
import OWL2.Sign
import OWL2.Theorem
import OWL2.ManchesterPrintBasic
import OWL2.Keywords
import OWL2.ColonKeywords

import Data.Function
import Data.List
import qualified Data.Map as Map
import qualified Data.Set as Set

-- | OWL2 signature printing

printOneNamed :: Anno.Named Axiom -> Doc
printOneNamed ns = printAxiom
  $ (if Anno.isAxiom ns then rmImplied else addImplied) $ Anno.sentence ns

delTopic :: Extended -> Sign -> Sign
delTopic e s = case e of
  ClassEntity (Expression c) -> s { concepts = Set.delete c $ concepts s }
  ObjectEntity (ObjectProp o) -> s
    { objectProperties = Set.delete o $ objectProperties s }
  SimpleEntity et -> execState (modEntity Set.delete et) s
  _ -> s

groupAxioms :: [Axiom] -> [Frame]
groupAxioms =
  concatMap (\ l@(PlainAxiom e _ : _) -> case e of
    Misc _ -> map (Frame e . (: []) . axiomBit) l
    _ -> [Frame e $ map axiomBit l])
  . groupBy (on (==) axiomTopic) . sortBy (on compare axiomTopic)

printOWLBasicTheory :: (Sign, [Named Axiom]) -> Doc
printOWLBasicTheory = printBasicTheory . prepareBasicTheory

prepareBasicTheory :: (Sign, [Named Axiom]) -> (Sign, [Named Axiom])
prepareBasicTheory (s, l) =
  (s { prefixMap = Map.union (prefixMap s) predefPrefixes }, l)

printBasicTheory :: (Sign, [Named Axiom]) -> Doc
printBasicTheory = printOntologyDocument . convertBasicTheory

convertBasicTheory :: (Sign, [Named Axiom]) -> OntologyDocument
convertBasicTheory (sig, l) = let
  (axs, ths) = partition Anno.isAxiom l
  cnvrt f = map f . groupAxioms . map Anno.sentence
  s = foldr (delTopic . axiomTopic . sentence) sig l
  in OntologyDocument (prefixMap s) $ emptyOntology
  $ toDecl s ++ cnvrt rmImpliedFrame axs ++ cnvrt addImpliedFrame ths

printSignElem :: Pretty a => Sign -> String -> (Sign -> Set.Set a) -> Doc
printSignElem s ty f = vcat $ map (\ t -> keyword ty <+> pretty t)
    $ Set.toList $ f s

printSignElem2 :: Sign -> String -> (Sign -> Set.Set a, a -> Doc) -> Doc
printSignElem2 s ty (f, g) = vcat $ map (\ t -> keyword ty <+> g t)
    $ Set.toList $ f s

printSign :: Sign -> Doc
printSign s = vcat
    (map (\ (c, l) -> hsep $ map text [prefixC, c ++ ":", '<' : l ++ ">"])
    $ Map.toList $ prefixMap s)
        $++$ foldl1 ($++$) (map (uncurry $ printSignElem2 s)
                [ (datatypeC, (datatypes, printIRI))
                , (classC, (concepts, printIRI))
                , (objectPropertyC, (objectProperties, printIRI))
                , (dataPropertyC, (dataProperties, printIRI))
                , (individualC, (individuals, printIRI))
                , (annotationPropertyC, (annotationRoles, printIRI)) ])

printFact :: Fact -> Doc
printFact pf = case pf of
    ObjectPropertyFact pn op i -> printPositiveOrNegative pn
           <+> pretty op <+> printIRI i
    DataPropertyFact pn dp l -> printPositiveOrNegative pn
           <+> printIRI dp <+> pretty l

-- | ListFrameBits only with relations
printListFrameBit :: ListFrameBit -> Doc
printListFrameBit lfb = case lfb of
    AnnotationBit a -> printAnnotatedList2 printIRI a
    ExpressionBit a -> printAnnotatedList2 printClassExpression a
    ObjectBit a -> printAnnotatedList2 printObjPropExp a
    DataBit a -> printAnnotatedList2 printIRI a
    IndividualSameOrDifferent a -> printAnnotatedList2 printIRI a
    _ -> empty

printMisc :: Pretty a => Annotations -> (b -> Doc) -> b -> AnnotatedList a
    -> Doc
printMisc a f r anl = f r <+> (printAnnotations a $+$ printAnnotatedList anl)

printMisc2 g a f r anl = f r <+> (printAnnotations a $+$ printAnnotatedList2 g anl)

-- | Misc ListFrameBits
printMiscBit :: Relation -> Annotations -> ListFrameBit -> Doc
printMiscBit r a lfb = case lfb of
    ExpressionBit anl -> printMisc2 printClassExpression a printEquivOrDisjointClasses (getED r) anl
    ObjectBit anl -> printMisc2 printObjPropExp a printEquivOrDisjointProp (getED r) anl
    DataBit anl -> printMisc2 printIRI a printEquivOrDisjointProp (getED r) anl
    IndividualSameOrDifferent anl ->
        printMisc2 printIRI a printSameOrDifferentInd (getSD r) anl
    _ -> empty

printAnnFrameBit :: Annotations -> AnnFrameBit -> Doc
printAnnFrameBit a afb = case afb of
    AnnotationFrameBit _ -> printAnnotations a
    DatatypeBit x -> printAnnotations a
          $+$ keyword equivalentToC <+> pretty x
    ClassDisjointUnion x -> keyword disjointUnionOfC
      <+> (printAnnotations a
          $+$ vcat (punctuate comma ( map printClassExpression x )))
    ClassHasKey op dp -> keyword hasKeyC <+> (printAnnotations a
      $+$ vcat (punctuate comma $ map pretty op ++ map printIRI dp))
    ObjectSubPropertyChain opl -> keyword subPropertyChainC
      <+> (printAnnotations a $+$ fsep (prepPunctuate (keyword oS <> space)
          $ map pretty opl))
    DataFunctional -> keyword characteristicsC <+>
          (printAnnotations a $+$ printCharact functionalS)

printFrameBit :: FrameBit -> Doc
printFrameBit fb = case fb of
    ListFrameBit r lfb -> case r of
        Just rel -> printRelation rel <+> printListFrameBit lfb
        Nothing -> case lfb of
            ObjectCharacteristics x -> keyword characteristicsC
                <+> printAnnotatedList x
            DataPropRange x -> keyword rangeC <+> printAnnotatedList x
            IndividualFacts x -> keyword factsC <+> (vcat $  map
                                  ( \ (ans, a) -> printAnnotations ans $+$ printFact a) x)
            _ -> empty
    AnnFrameBit a afb -> printAnnFrameBit a afb


printFrame :: Frame -> Doc
printFrame (Frame eith bl) = case eith of
    SimpleEntity (Entity _ e uri) -> keyword (showEntityType e) <+>
            fsep [printIRI uri $+$ vcat (map printFrameBit bl)]
    ObjectEntity ope -> keyword objectPropertyC <+>
            (printObjPropExp ope $+$ fsep [vcat (map printFrameBit bl)])
    ClassEntity ce -> keyword classC <+>
            (printClassExpression ce $+$ fsep [vcat (map printFrameBit bl)])
    Misc a -> case bl of
        [ListFrameBit (Just r) lfb] -> printMiscBit r a lfb
        [AnnFrameBit ans (AnnotationFrameBit Assertion)] ->
            let [Annotation _ iri _] = a
            in keyword individualC <+> (printIRI iri $+$ printAnnotations ans)
        h : r -> printFrame (Frame eith [h])
          $+$ printFrame (Frame eith r)
        [] -> empty

printAxiom :: Axiom -> Doc
printAxiom (PlainAxiom e fb) = printFrame (Frame e [fb])

printImport :: ImportIRI -> Doc
printImport x = keyword importC <+> printIRI x

printPrefixes :: PrefixMap -> Doc
printPrefixes x = vcat (map (\ (a, b) ->
       (text "Prefix:" <+> text a <> colon <+> text ('<' : b ++ ">")))
          (Map.toList x))

-- | Printing the ontology

printOntology :: Ontology -> Doc
printOntology Ontology {name = a, imports = b, ann = c, ontFrames = d} =
    (if nullQName == a then empty else keyword ontologyC <+> printIRI a)
    $++$ vcat (map printImport b)
    $++$ vcat (map printAnnotations c) $+$ vcat (map printFrame d)

printOntologyDocument :: OntologyDocument -> Doc
printOntologyDocument OntologyDocument {prefixDeclaration = a, ontology = b} =
    printPrefixes a $++$ printOntology b

