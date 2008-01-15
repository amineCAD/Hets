{- |
Module      :  $Header$
Description :  abstract syntax for CASL_DL logic extension of CASL
Copyright   :  (c) Klaus L�ttich, Uni Bremen 2004
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  luecke@informatik.uni-bremen.de
Stability   :  provisional
Portability :  portable

Abstract syntax for CASL_DL logic extension of CASL
  Only the added syntax is specified
-}

module CASL_DL.AS_CASL_DL where

import Common.Id
import Common.AS_Annotation
import CASL.AS_Basic_CASL

-- DrIFT command
{-! global: UpPos !-}

type DL_BASIC_SPEC = BASIC_SPEC () () DL_FORMULA

type AnDLFORM = Annoted (FORMULA DL_FORMULA)

data CardType = CMin | CMax | CExact deriving (Eq, Ord)

minCardinalityS, maxCardinalityS, cardinalityS :: String
cardinalityS = "cardinality"
minCardinalityS = "minC" ++ tail cardinalityS
maxCardinalityS = "maxC" ++ tail cardinalityS

instance Show CardType where
    show ct = case ct of
        CMin -> minCardinalityS
        CMax -> maxCardinalityS
        CExact -> cardinalityS

-- | for a detailed specification of all the components look into the sources
data DL_FORMULA =
    Cardinality CardType
                PRED_SYMB -- refers to a declared (binary) predicate
                (TERM DL_FORMULA)
                -- this term is restricted to constructors
                -- denoting a (typed) variable
                (TERM DL_FORMULA)
               -- the second term is restricted to an Application denoting
               -- a literal of type nonNegativeInteger (Nat)
                Range
               -- position of keyword, brackets, parens and comma
             deriving (Eq, Ord, Show)

caslDLCardTypes :: [CardType]
caslDLCardTypes = [CExact, CMin, CMax]

casl_DL_reserved_words :: [String]
casl_DL_reserved_words = map show caslDLCardTypes


-- Manchester Abstract Syntax
{-
data Concept = ClassId Id | And Concept Concept | ...
data ClassProperty = SubClassof Concept 
                     | EquivalentTo Concept 
                     | DisjointWith Concept
data BasicItem = ...
-}
