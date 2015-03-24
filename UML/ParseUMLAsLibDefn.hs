module UML.ParseUMLAsLibDefn where

import Syntax.AS_Library
import Syntax.AS_Structured
import Common.AS_Annotation
import Common.IRI
import Common.Id
import Common.LibName

import UML.UML
import UML.Logic_UML
import UML.Parser 

import Logic.Grothendieck

import System.IO
parseUMLCDasLibDefn :: FilePath -> IO LIB_DEFN
parseUMLCDasLibDefn    fp = 
    do     
        handle <- openFile fp ReadMode
        contents <- hGetContents handle 
        return $ convertToLibDefN fp $ parseUMLCDfromString contents

convertToLibDefN :: FilePath -> CM -> LIB_DEFN
convertToLibDefN filename cm = Lib_defn
                                (emptyLibName $ convertFileToLibStr filename)
                                (makeLogicItem UML : [convertoItem cm])
                                nullRange 
                                []

convertoItem :: CM -> Annoted LIB_ITEM
convertoItem el = makeSpecItem (simpleIdToIRI $ mkSimpleId $ cmName el) $ createSpec el

createSpec :: CM -> Annoted SPEC
createSpec el = makeSpec $ G_basic_spec UML el
