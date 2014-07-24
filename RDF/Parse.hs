{- |
Module      :  $Header$
Copyright   :  (c) Felix Gabriel Mance
License     :  GPLv2 or higher, see LICENSE.txt

Maintainer  :  f.mance@jacobs-university.de
Stability   :  provisional
Portability :  portable

RDF syntax parser
-}

module RDF.Parse where

import Common.Parsec
import Common.Lexer
import Common.AnnoParser (newlineOrEof)
import Common.Token (criticalKeywords)
import Common.Id hiding (sourceLine, incSourceColumn)
import qualified Common.GlobalAnnotations as GA (PrefixMap)

import OWL2.AS
import OWL2.Parse hiding (stringLiteral, literal, skips, uriP)
import RDF.AS
import RDF.Symbols

import Data.Either
import qualified Data.Map as Map
import Text.ParserCombinators.Parsec

uriP :: CharParser st QName
uriP = do
  pos <- getPosition
  ret <- (skips $ try $ checkWithUsing showQN uriQ $ \ q ->
    not (null $ namePrefix q) || notElem (localPart q) criticalKeywords)
   >>= \v -> return $ if null (namePrefix v)
                     then v { localPart = case localPart v of
                               ':':v' -> v'
                               _ -> if iriType v /= Full then
                                     error $ "RDF.Parse.uriP " ++ show v
                                    else localPart v }
                     else v
  case reverse $ localPart ret of
          c:l -> do
                    pos1 <- getPosition
                    if sourceLine pos /= sourceLine pos1 && elem c ".;" then
                      do
                        let pos2 = incSourceColumn pos (length l+1)
                        setPosition pos2
                        i <- getInput
                        setInput $ c:'\n':i
                        return $ ret {localPart = reverse l}
                    else return ret
          _ -> return ret

-- * hets symbols parser

rdfEntityType :: CharParser st RDFEntityType
rdfEntityType = choice $ map (\ f -> keyword (show f) >> return f)
  rdfEntityTypes

{- | parses an entity type (subject, predicate or object) followed by a
comma separated list of IRIs -}
rdfSymbItems :: GenParser Char st SymbItems
rdfSymbItems = do
    ext <- optionMaybe rdfEntityType
    iris <- rdfSymbs
    return $ SymbItems ext iris

-- | parse a comma separated list of uris
rdfSymbs :: GenParser Char st [IRI]
rdfSymbs = uriP >>= \ u -> do
    commaP `followedWith` uriP
    us <- rdfSymbs
    return $ u : us
  <|> return [u]

-- | parse a possibly kinded list of comma separated symbol pairs
rdfSymbMapItems :: GenParser Char st SymbMapItems
rdfSymbMapItems = do
  ext <- optionMaybe rdfEntityType
  iris <- rdfSymbPairs
  return $ SymbMapItems ext iris

-- | parse a comma separated list of uri pairs
rdfSymbPairs :: GenParser Char st [(IRI, Maybe IRI)]
rdfSymbPairs = uriPair >>= \ u -> do
    commaP `followedWith` uriP
    us <- rdfSymbPairs
    return $ u : us
  <|> return [u]

-- * turtle syntax parser

resource :: CharParser st ()
resource  = try (uriRef <|> qname)
 where uriRef = char '<' >>
                relativeURI >>
                char '>' >> return ()
       relativeURI = many (escapeChar <|> many1 (noneOf ">"))
       qname = do
                  many space
                  optional (try name)
                  char ':'
                  optional (try name)
                  return ()
       name = many $ noneOf " :."

resourceP :: CharParser st QName
resourceP = skips ((lookAhead resource >> uriP) <|>
                   (many space >> string "a" >> return rdfType))

skips :: CharParser st a -> CharParser st a
skips = (<< skipMany
        (forget space <|> parseComment <|> nestCommentOut <?> ""))

charOrQuoteEscape :: CharParser st String
charOrQuoteEscape = try (string "\\\"") <|> fmap return anyChar

longLiteral :: CharParser st (String, Bool)
longLiteral = do
    string "\"\"\""
    ls <- flat $ manyTill charOrQuoteEscape $ try $ string "\"\"\""
    return (ls, True)

shortLiteral :: CharParser st (String, Bool)
shortLiteral = do
    char '"'
    ls <- flat $ manyTill charOrQuoteEscape $ try $ string "\""
    return (ls, False)

stringLiteral :: CharParser st RDFLiteral
stringLiteral = do
  (s, b) <- try longLiteral <|> shortLiteral
  do
      string cTypeS
      d <- datatypeUri
      return $ RDFLiteral b s $ Typed d
    <|> do
        string "@"
        t <- skips $ optionMaybe languageTag
        return $ RDFLiteral b s $ Untyped t
    <|> skips (return $ RDFLiteral b s $ Untyped Nothing)

intLitToInt :: IntLit -> Int
intLitToInt (IntLit (NNInt l) b) =
  let toInt _ []    = 0
      toInt e (i:l') = i*10^e + toInt (e-1) l'
  in (if b then -1 else 1) * toInt (length l) l

floatToDec :: FloatLit -> DecLit
floatToDec (FloatLit (DecLit t f) e) =
  let e' = intLitToInt e
      NNInt t' = absInt t
      NNInt f' = f
  in if e' >= 0
     then DecLit (t {absInt = NNInt (t' ++ take e' (f' ++ repeat 0))})
                 (NNInt (drop e' f'))
     else DecLit (t {absInt = NNInt (reverse (drop (abs e') (reverse t')))})
                 (NNInt (f' ++ reverse (take (abs e') ((reverse t') ++ repeat 0))))

literal :: CharParser st RDFLiteral
literal = (try $ do
    c <- optionMaybe $ char '"'
    f <- skips $ try floatingPointLit
         <|> fmap decToFloat decimalLit
    case c of
      Just _  -> char '"'
      Nothing -> return '"'
    uri <- skips $ case c of
                     Just  _ -> do
                            string cTypeS
                            iri <- datatypeUri
                            return . Just $ iri
                     Nothing -> return Nothing
    f1  <- case uri of
        Nothing -> return f
        Just iri | iri == xmlInteger -> return . intToFloat . floatToInt $ f
        Just iri | iri == xmlDecimal -> let b = floatBase f
                                            frac = case fracDec b of
                                                    NNInt [] -> NNInt [0]
                                                    frac'-> frac'
                                        in return . decToFloat . floatToDec $ f { floatBase = b { fracDec = frac } }
        Just iri | iri == xmlDouble  -> let b = floatBase f
                                            frac = case fracDec b of
                                                    NNInt [] -> NNInt [0]
                                                    frac'-> frac'
                                        in return . decToFloat . floatToDec $ f { floatBase = b { fracDec = frac } }
        Just iri -> fail $ "Not a recognized numeric literal type " ++ showQU iri
    return $ RDFNumberLit f1)
  <|> (do
          b <- try $ skips $ string "true" <|> string "false"
          return $ RDFLiteral False b (Typed xmlBoolean))
  <|> stringLiteral

parseBase :: CharParser st Base
parseBase = do
    pkeyword "@base"
    base <- skips uriP
    skips $ char '.'
    return $ Base base

parsePrefix :: CharParser st Prefix
parsePrefix = do
    pkeyword "@prefix"
    p <- skips (option "" prefix << char ':')
    i <- skips uriP
    skips $ char '.'
    return $ Prefix p i

parsePredicate :: CharParser st Predicate
parsePredicate = fmap Predicate $ skips resourceP

parseSubject :: CharParser st Subject
parseSubject =
    fmap Subject (skips resourceP)
  <|> fmap SubjectList
            (between (skips $ char '[') (skips $ char ']') $ skips parsePredObjList)
  <|> fmap SubjectCollection
            (between (skips $ char '(') (skips $ char ')') $ many parseObject)
  <|> (string "_:" >> fmap BlankNode (skips $ many $ noneOf " :"))

parseObject :: CharParser st Object
parseObject = fmap ObjectLiteral literal <|> fmap Object parseSubject

parsePredObjects :: CharParser st PredicateObjectList
parsePredObjects = do
    pr <- parsePredicate
    objs <- sepBy parseObject $ skips $ char ','
    return $ PredicateObjectList pr objs

parsePredObjList :: CharParser st [PredicateObjectList]
parsePredObjList = sepEndBy parsePredObjects $ skips $ char ';'

parseTriples :: CharParser st Triples
parseTriples = do
    s <- parseSubject
    ls <- parsePredObjList
    skips $ char '.'
    return $ Triples s ls

parseComment :: CharParser st ()
parseComment = do
    tryString "#"
    forget $ skips $ manyTill anyChar newlineOrEof

parseStatement :: CharParser st Statement
parseStatement = fmap BaseStatement parseBase
    <|> fmap PrefixStatement parsePrefix <|> fmap Statement parseTriples

basicSpec :: GA.PrefixMap -> CharParser st TurtleDocument
basicSpec pm = do
    many parseComment
    ls <- many parseStatement
    let td = TurtleDocument
             dummyQName (Map.map transIri $ convertPrefixMap pm) ls
-- return $ trace (show $ Map.union predefinedPrefixes (prefixMap td)) td
    return td
  where transIri s = QN "" s Full s nullRange

predefinedPrefixes :: RDFPrefixMap
predefinedPrefixes = Map.fromList $ zip
    ["rdf", "rdfs", "dc", "owl", "ex", "xsd"]
    $ rights $ map (parse uriQ "")
    [ "<http://www.w3.org/1999/02/22-rdf-syntax-ns#>"
    , "<http://www.w3.org/2000/01/rdf-schema#>"
    , "<http://purl.org/dc/elements/1.1/>"
    , "<http://www.w3.org/2002/07/owl#>"
    , "<http://www.example.org/>"
    , "<http://www.w3.org/2001/XMLSchema#>" ]
