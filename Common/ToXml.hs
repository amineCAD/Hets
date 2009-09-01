{- |
Module      :  $Header$
Description :  xml utilities
Copyright   :  (c) Christian Maeder, DFKI GmbH 2009
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt
Maintainer  :  Christian.Maeder@dfki.de
Stability   :  provisional
Portability :  portable

xml utilities on top of the xml light package and common hets data types
-}

module Common.ToXml where

import Common.AS_Annotation
import Common.DocUtils
import Common.GlobalAnnotations
import Common.Id
import Common.Result

import Text.XML.Light

mkAttr :: String -> String -> Attr
mkAttr = Attr . unqual

prettyElem :: Pretty a => String -> GlobalAnnos -> a -> Element
prettyElem name ga a = unode name $ showGlobalDoc ga a ""

rangeAttrs :: Range -> [Attr]
rangeAttrs rg = case rangeToList rg of
  [] -> []
  ps -> [mkAttr "range" $ show $ prettyRange ps]

mkNameAttr :: String -> Attr
mkNameAttr = mkAttr "name"

annotation :: GlobalAnnos -> Annotation -> Element
annotation ga a = add_attrs (rangeAttrs $ getRangeSpan a)
  $ prettyElem "Annotation" ga a

annotations :: GlobalAnnos -> [Annotation] -> [Element]
annotations = map . annotation

subnodes :: String -> [Element] -> [Element]
subnodes name elems = if null elems then [] else [unode name elems]
