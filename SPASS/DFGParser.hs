{- |
Module      :  $Header$
Copyright   :  (c) C. Immanuel Normann and Uni Bremen 2007
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  i.normann@iu-bremen.de
Stability   :  provisional


A parser for the SPASS Input Syntax taken from <http://spass.mpi-sb.mpg.de/download/binaries/spass-input-syntax15.pdf >.
In this version the non-terminals /settings, declaration_list, clause_list,/ and /proof_list/ are currentliy not supported.

-}

module SPASS.DFGParser where

import Text.ParserCombinators.Parsec
import Text.ParserCombinators.Parsec.Prim
import qualified Common.Lexer as Lexer
import qualified Text.ParserCombinators.Parsec.Token as PT
import SPASS.Sign
import Common.AS_Annotation
import qualified Common.Lexer as CL

-- ----------------------------------------------
-- * SPASS Language Definition
-- ----------------------------------------------

spassDef :: PT.LanguageDef st
spassDef    
 = PT.LanguageDef 
   { PT.commentStart   = ""--"{*"
   , PT.commentEnd     = ""--"*}"
   , PT.commentLine    = "%"
   , PT.nestedComments = False
   , PT.identStart     = alphaNum
   , PT.identLetter    = alphaNum <|> oneOf "_'"
   , PT.opStart        = letter -- brauche ich nicht
   , PT.opLetter       = letter --
   , PT.reservedOpNames= []
   , PT.reservedNames  = ["forall", "exists", "equal", "true", "false", "or", "and", "not", "implies", "implied", "equiv"]
   , PT.caseSensitive  = True
   }

-- begin helpers ----------------------------------------------------------

lexer :: PT.TokenParser st
lexer = PT.makeTokenParser spassDef

comma = PT.comma lexer
dot = PT.dot lexer
commaSep1 = PT.commaSep1 lexer
parens = PT.parens lexer
squares = PT.squares lexer
symbolT = PT.symbol lexer
natural = PT.natural lexer
whiteSpace = PT.whiteSpace lexer

parensDot :: CharParser st a -> GenParser Char st a
parensDot p = parens p << dot
squaresDot p = squares p << dot

text = string "{*" >> (manyTill anyChar (try (string "*}")))
{-
*SPASS.Parser> run text "{* mein Kommentar *}"
" mein Kommentar "
-}

identifierT = PT.identifier lexer

list_of sort = try $ string $ "list_of_" ++ sort
list_of_dot sort = list_of (sort ++ ".") 
end_of_list = symbolT "end_of_list."

oneOfTokens ls = choice (map (try . symbolT) ls)
{-
*SPASS.Parser> run (oneOfTokens ["ab","cd"]) "abcd"
"ab"
-}

mapTokensToData ls = choice (map (try . tokenToData) ls)
    where tokenToData (s,t) = symbolT s >> return t

maybeParser p = option Nothing (do {r <- p; return (Just r)})

-- end helpers ----------------------------------------------------------



-- ** SPASS Problem
{- |
   This is the main function of the module
-}

{-
  begin_problem(Unknown).list_of_descriptions.name({* Test *}).author({* me *}).status(satisfiable).description({* nothing CNF generated by FLOTTER V 2.8 *}).end_of_list.list_of_symbols.predicates[(a, 0), (b, 0)].end_of_list.list_of_clauses(axioms, cnf).clause(or(not(a),b),1).clause(or(not(b),not(a)),2).end_of_list.list_of_clauses(conjectures, cnf).end_of_list.list_of_settings(SPASS).{*set_ClauseFormulaRelation((1,axiom0),(2,axiom1)).*}end_of_list.end_problem.
-}
parseSPASS :: GenParser Char st SPProblem
parseSPASS = whiteSpace >> problem

problem :: GenParser Char st SPProblem
problem = do symbolT "begin_problem"
	     i  <- parensDot identifierT
             skipMany (oneOf CL.whiteChars)
	     dl <- description_list
             skipMany (oneOf CL.whiteChars)
	     lp <- logical_part
	     skipMany (oneOf CL.whiteChars)
             s  <- settings_list
	     symbolT "end_problem."
             many anyChar
             eof
	     return (SPProblem
		     {identifier = i,
                      description = dl,
                      logicalPart = lp,
                      settings = []})

-- ** SPASS Desciptions

{- |
  A description is mandatory for a SPASS problem. It has to specify at least
  a 'name', the name of the 'author', the 'status' (see also 'SPLogState' below),
  and a (verbose) description.
-}
description_list :: GenParser Char st SPDescription
description_list = do list_of_dot "descriptions"
                      skipMany (oneOf CL.whiteChars)
		      n <- symbolT "name" >> parensDot text
		      skipMany (oneOf CL.whiteChars)
                      a <- symbolT "author" >> parensDot text
		      skipMany (oneOf CL.whiteChars)
                      v <- maybeParser (symbolT "version" >> parensDot text)
		      skipMany (oneOf CL.whiteChars)
                      l <- maybeParser (symbolT "logic" >> parensDot text)
		      skipMany (oneOf CL.whiteChars)
                      s <- symbolT "status" >> parensDot (mapTokensToData
								[("satisfiable",SPStateSatisfiable),
								 ("unsatisfiable",SPStateUnsatisfiable),
								 ("unknown",SPStateUnknown)])
		      de <- symbolT "description" >> parensDot text
		      da <- maybeParser (symbolT "date" >> parensDot text)
		      end_of_list
		      return (SPDescription
			      {name = n, author = a, version = v, logic = l,
                               status = s, desc = de, date = da})

-- SPASS Settings not yet supported
settings_list :: GenParser Char st [SPSetting]
settings_list = do list_of "settings"
                   skipMany (oneOf CL.whiteChars)
                   Lexer.oParenT
                   many $ noneOf[')']
                   Lexer.cParenT
                   dot
                   char '{'
                   many $ noneOf['}']
                   char '}'
                   skipMany (oneOf CL.whiteChars)
                   end_of_list
                   skipMany (oneOf CL.whiteChars)
                   return []


-- ** SPASS Logical Parts

{- |
  A SPASS logical part consists of a symbol list, a declaration list, and a
  set of formula lists. Support for clause lists and proof lists hasn't
  been implemented yet.
-}
logical_part :: GenParser Char st SPLogicalPart
logical_part = do sl <- maybeParser symbol_list
		  --dl <- declaration_list  -- braucht man nicht fuer mptp
                  fs <- many formula_list
                  cl <- many clause_list   -- braucht man nicht fuer mptp
		  --pl <- many proof_list  -- braucht man nicht fuer mptp
		  return (SPLogicalPart
			  {symbolList = sl,
                           declarationList = [],
                           formulaLists = fs,
                           clauseLists = cl})
--                        proofLists :: [SPProofList]



-- *** Symbol List

{- |
  SPASS Symbol List
-}
symbol_list :: GenParser Char st SPSymbolList
symbol_list = do list_of_dot "symbols"
		 fs <- option [] (signSymFor "functions")
                 skipMany (oneOf CL.whiteChars)
		 ps <- option [] (signSymFor "predicates")
                 skipMany (oneOf CL.whiteChars)
		 ss <- option [] (signSymFor "sorts")
                 skipMany (oneOf CL.whiteChars)
		 end_of_list
		 return (SPSymbolList
			 {functions = fs,
			  predicates = ps,
			  sorts = ss,
			  operators = [],     -- not supported in dfg-syntax version 1.5
			  quantifiers = []})  -- not supported in dfg-syntax version 1.5
{-
*SPASS.Parser> run symbol_list "list_of_symbols.functions[(f,2), (a,0), (b,0), (c,0)].predicates[(F,2)].end_of_list."
SPSymbolList {functions = [SPSignSym {sym = "f", arity = 2},SPSignSym {sym = "a", arity = 0},SPSignSym {sym = "b", arity = 0},SPSignSym {sym = "c", arity = 0}], predicates = [SPSignSym {sym = "F", arity = 2}], sorts = [], operators = [], quantifiers = []}
-}

signSymFor kind = symbolT kind >> squaresDot (commaSep1 $ parens signSym)
signSym = do s <- identifierT
	     a <- maybeParser (comma >> natural) -- option Nothing ((do {comma; n <- natural; return (Just n)}))
	     return (case a
		     of (Just a) -> SPSignSym {sym = s, arity = fromInteger a}
		        Nothing -> SPSimpleSignSym s)


--declaration_list, clause_list, proof_list are currently not supported

-- *** Formula List

{- |
  SPASS Formula List
-}
formula_list :: GenParser Char st SPFormulaList
formula_list = do list_of "formulae"
                  ot <- parens (mapTokensToData [("axioms",SPOriginAxioms),
						 ("conjectures",SPOriginConjectures)])
                  dot
		  fs <- many (formula (case ot of {SPOriginAxioms -> True; _ -> False}))
                  end_of_list
                  return (SPFormulaList { originType = ot,
					  formulae = fs })

{-
*SPASS.Parser> run formula_list "list_of_formulae(axioms).formula(all([a,b],R(a,b)),bla).end_of_list."
SPFormulaList {originType = SPOriginAxioms, formulae = [NamedSen {senName = "bla", isAxiom = True, isDef = False, sentence = SPQuantTerm {quantSym = SPCustomQuantSym "all", variableList = [SPSimpleTerm (SPCustomSymbol "a"),SPSimpleTerm (SPCustomSymbol "b")], qFormula = SPComplexTerm {symbol = SPCustomSymbol "R", arguments = [SPSimpleTerm (SPCustomSymbol "a"),SPSimpleTerm (SPCustomSymbol "b")]}}}]}
*SPASS.Parser> run formula_list "list_of_formulae(axioms).formula(forall([a,b],R(a,b)),bla).end_of_list."
SPFormulaList {originType = SPOriginAxioms, formulae = [NamedSen {senName = "bla", isAxiom = True, isDef = False, sentence = SPQuantTerm {quantSym = SPForall, variableList = [SPSimpleTerm (SPCustomSymbol "a"),SPSimpleTerm (SPCustomSymbol "b")], qFormula = SPComplexTerm {symbol = SPCustomSymbol "R", arguments = [SPSimpleTerm (SPCustomSymbol "a"),SPSimpleTerm (SPCustomSymbol "b")]}}}]}
*SPASS.Parser> run formula_list "list_of_formulae(axioms).formula(forall([a,b],equiv(a,b)),bla).end_of_list."
SPFormulaList {originType = SPOriginAxioms, formulae = [NamedSen {senName = "bla", isAxiom = True, isDef = False, sentence = SPQuantTerm {quantSym = SPForall, variableList = [SPSimpleTerm (SPCustomSymbol "a"),SPSimpleTerm (SPCustomSymbol "b")], qFormula = SPComplexTerm {symbol = SPEquiv, arguments = [SPSimpleTerm (SPCustomSymbol "a"),SPSimpleTerm (SPCustomSymbol "b")]}}}]}
-}

clause_list :: GenParser Char st SPClauseList
clause_list = do list_of "clauses"
                 Lexer.oParenT 
                 ot <-(mapTokensToData [("axioms",SPOriginAxioms),
					("conjectures",SPOriginConjectures)]) 
                 Lexer.commaT
                 ct <- (mapTokensToData [("cnf",SPCNF),
					 ("dnf",SPDNF)]) 
                 Lexer.cParenT
                 dot
                 fs <- many (clause (case ot of {SPOriginAxioms -> True; _ -> False}))
                 end_of_list
                 return (SPClauseList {  coriginType = ot,
                                         clauseType  = ct,
					 clauses = fs })

{-
run clause_list "list_of_clauses(axioms, cnf). clause(or(not(a),b),1). clause(or(not(b),not(a)),2).  end_of_list."
-}

clause :: Bool -> GenParser Char st (Named SPASS.Sign.SPTerm)
clause bool = symbolT "clause"
	       >> parensDot (do sen <- cterm
			        name <- (option "" (comma >> identifierT))
			        return (NamedSen
					{senName = name,
					 isAxiom = bool, -- propagated from 'origin_type' of 'list_of_formulae'
					 isDef = False, -- this originTpe eedoes not exist
					 wasTheorem = False,
                                         sentence = sen}))

formula :: Bool -> GenParser Char st (Named SPASS.Sign.SPTerm)
formula bool = symbolT "formula"
	       >> parensDot (do sen <- term
			        name <- (option "" (comma >> identifierT))
			        return (NamedSen
					{senName = name,
					 isAxiom = bool, -- propagated from 'origin_type' of 'list_of_formulae'
					 isDef = False, -- this originTpe does not exist
					 wasTheorem = False,
                                         sentence = sen}))

-- *** Terms

{- |
  A SPASS Term.
-}

quantification :: SPQuantSym -> GenParser Char st SPTerm
quantification s = do (ts',t') <- parens (do ts <- squares (commaSep1 term) -- todo: var binding should allow only simple terms
                                             comma; t <- term
                                             return (ts,t))
                      return (SPQuantTerm
                              {quantSym = s,variableList = ts',qFormula = t'})

application :: SPSymbol -> GenParser Char st SPTerm
application s = do ts <- parens (commaSep1 term)
                   return (SPComplexTerm
			   {symbol = s, arguments = ts})

constant :: (Monad m) => SPSymbol -> m SPTerm
constant c = return (SPSimpleTerm c)

term :: GenParser Char st SPTerm
term = do s <- identifierT
          do {try (quantification (SPCustomQuantSym s)) 
	      <|> try (application (SPCustomSymbol s)) 
	      <|> (constant (SPCustomSymbol s))}
       <|>
       do q <- mapTokensToData [("forall",SPForall), ("exists",SPExists)]
	  quantification q
       <|>
       do a <- mapTokensToData [("equal",SPEqual), ("or",SPOr), ("and",SPAnd),("not",SPNot),
				("implies",SPImplies), ("implied",SPImplied),("equiv",SPEquiv)]
	  application a
       <|>
       do c <- mapTokensToData [("true",SPTrue), ("false",SPFalse)]
	  constant c

cterm :: GenParser Char st SPTerm
cterm = do s <- identifierT
           do {try (application (SPCustomSymbol s)) 
	       <|> (constant (SPCustomSymbol s))}
        <|>
        do a <- mapTokensToData [("or",SPOr), ("and",SPAnd),("not",SPNot)]
           application a
        <|>
        do c <- mapTokensToData [("true",SPTrue), ("false",SPFalse)]
	   constant c

-- ----------------------------------------------
-- * Monad and Functor extensions
-- ----------------------------------------------

bind :: (Monad m) => (a -> b -> c) -> m a -> m b -> m c
bind f p q = do { x <- p; y <- q; return (f x y) }

infixl <<

(<<) :: (Monad m) => m a -> m b -> m a
(<<) = bind const

infixr 5 <:>

(<:>) :: (Monad m) => m a -> m [a] -> m [a]
(<:>) = bind (:)

infixr 5 <++>

(<++>) :: (Monad m) => m [a] -> m [a] -> m [a]
(<++>) = bind (++)


run :: Show a => Parser a -> String -> IO ()
run p input
        = case (parse p "" input) of
            Left err -> do{ putStr "parse error at "
                          ; print err
                          }
            Right x  -> print x
