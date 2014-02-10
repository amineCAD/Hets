{- |
Module      :  $Header$
Description :  reading and parsing ATerms, CASL, HetCASL files
Copyright   :  (c) Klaus Luettich, C. Maeder, Uni Bremen 2002-2006
License     :  GPLv2 or higher, see LICENSE.txt

Maintainer  :  Christian.Maeder@dfki.de
Stability   :  provisional
Portability :  non-portable(DevGraph)

reading and parsing ATerms, CASL, HetCASL files as much as is needed for the
static analysis
-}

module Driver.ReadFn where

import Logic.Grothendieck

import ATC.Grothendieck

import Driver.Options

import ATerm.AbstractSyntax
import ATerm.ReadWrite

import Common.Http
import Common.Id
import Common.IO
import Common.IRI
import Common.Result
import Common.DocUtils
import Common.LibName

import Text.XML.Light

import System.FilePath
import System.Directory

import Control.Monad.Trans (MonadIO (..))

import Data.List (isPrefixOf, stripPrefix)
import Data.Maybe

noPrefix :: QName -> Bool
noPrefix = isNothing . qPrefix

isDgXml :: QName -> Bool
isDgXml q = qName q == "DGraph" && noPrefix q

isPpXml :: QName -> Bool
isPpXml q = qName q == "Lib" && noPrefix q

isDMU :: QName -> Bool
isDMU q = qName q == "ClashResult" && noPrefix q

isRDF :: QName -> Bool
isRDF q = qName q == "RDF" && qPrefix q == Just "rdf"

isOWLOnto :: QName -> Bool
isOWLOnto q = qName q == "Ontology" && qPrefix q == Just "owl"

guessXmlContent :: String -> Either String InType
guessXmlContent str = case parseXMLDoc str of
  Nothing -> Right GuessIn
  Just e -> let q = elName e in
    if isDgXml q then Right DgXml else
    if isRDF q then
      Right $ if any (isOWLOnto . elName) $ elChildren e then OWLIn else RDFIn
    else if isDMU q then Left "DMU" else
       if isPpXml q then Left ".pp.xml" else Right GuessIn

guessInput :: MonadIO m => HetcatsOpts -> FilePath -> String -> m InType
guessInput opts file input = let fty = guess file (intype opts) in
  if elem fty [GuessIn, DgXml, RDFIn] then case guessXmlContent input of
    Left ty -> fail $ "unexpected xml format: " ++ ty
    Right ty -> if ty == DgXml then fail "unexpected DGraph xml"
      else return ty
  else return fty

isDgXmlFile :: HetcatsOpts -> FilePath -> String -> Bool
isDgXmlFile opts file content = guess file (intype opts) == DgXml
        && guessXmlContent content == Right DgXml

readShATermFile :: ShATermLG a => LogicGraph -> FilePath -> IO (Result a)
readShATermFile lg fp = do
    str <- readFile fp
    return $ fromShATermString lg str

fromVersionedATT :: ShATermLG a => LogicGraph -> ATermTable -> Result a
fromVersionedATT lg att =
    case getATerm att of
    ShAAppl "hets" [versionnr, aterm] [] ->
        if hetsVersion == snd (fromShATermLG lg versionnr att)
        then Result [] (Just $ snd $ fromShATermLG lg aterm att)
        else Result [Diag Warning
                     "Wrong version number ... re-analyzing"
                     nullRange] Nothing
    _ -> Result [Diag Warning
                   "Couldn't convert ShATerm back from ATermTable"
                   nullRange] Nothing

fromShATermString :: ShATermLG a => LogicGraph -> String -> Result a
fromShATermString lg str = if null str then
    Result [Diag Warning "got empty string from file" nullRange] Nothing
    else fromVersionedATT lg $ readATerm str

readVerbose :: ShATermLG a => LogicGraph -> HetcatsOpts -> LibName -> FilePath
            -> IO (Maybe a)
readVerbose lg opts ln file = do
    putIfVerbose opts 2 $ "Reading " ++ file
    Result ds mgc <- readShATermFile lg file
    showDiags opts ds
    case mgc of
      Nothing -> return Nothing
      Just (ln2, a) -> if ln2 == ln then return $ Just a else do
        putIfVerbose opts 0 $ "incompatible library names: "
               ++ showDoc ln " (requested) vs. "
               ++ showDoc ln2 " (found)"
        return Nothing

-- | create a file name without suffix from a library name
libNameToFile :: LibName -> FilePath
libNameToFile ln = maybe (libToFileName ln)
  (rmSuffix . iriToStringUnsecure) $ locIRI ln

findFileOfLibNameAux :: HetcatsOpts -> FilePath -> IO (Maybe FilePath)
findFileOfLibNameAux opts file = do
          let fs = map (</> file) $ "" : libdirs opts
          ms <- mapM (existsAnSource opts) fs
          return $ case catMaybes ms of
            [] -> Nothing
            f : _ -> Just f

findFileOfLibName :: HetcatsOpts -> FilePath -> IO (Maybe FilePath)
findFileOfLibName opts = findFileOfLibNameAux opts { intype = GuessIn }

-- | convert a file name that may have a suffix to a library name
fileToLibName :: HetcatsOpts -> FilePath -> LibName
fileToLibName opts efile =
    let paths = libdirs opts
        file = rmSuffix efile -- cut of extension
        pps = filter snd $ map (\ p -> (p, isPrefixOf p file)) paths
    in emptyLibName $ case pps of
         [] -> if useLibPos opts then convertFileToLibStr file
            else mkLibStr file
         (path, _) : _ -> mkLibStr $ drop (length path) file
                   -- cut off libdir prefix

downloadSource :: HetcatsOpts -> FilePath -> IO (Either String String)
downloadSource opts fn =
  if checkUri fn then loadFromUri fn else do
    b <- doesFileExist fn
    if b then catchIOException (Left $ "could not read file: " ++ fn)
        . fmap Right $ readEncFile (ioEncoding opts) fn
      else return $ Left $ "file does not exist: " ++ fn

tryDownload :: HetcatsOpts -> [FilePath] -> FilePath
  -> IO (Either String (FilePath, String))
tryDownload opts fnames fn = case fnames of
  [] -> return $ Left $ "no input found for: " ++ fn
  fname : fnames' -> do
       mRes <- downloadSource opts fname
       case mRes of
         Left _ -> tryDownload opts fnames' fn
         Right cont -> return $ Right (fname, cont)

getContent :: HetcatsOpts -> FilePath
  -> IO (Either String (FilePath, String))
getContent opts = getExtContent opts (getExtensions opts)

getExtContent :: HetcatsOpts -> [String] -> FilePath
  -> IO (Either String (FilePath, String))
getExtContent opts exts fp =
  let fn = fromMaybe fp $ stripPrefix "file://" fp
      fs = getFileNames exts fn
      ffs = if checkUri fn || isAbsolute fn then fs else
           concatMap (\ d -> map (d </>) fs) $ "" : libdirs opts
  in tryDownload opts ffs fn
