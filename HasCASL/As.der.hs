{- |
Module      :  $Header$
Copyright   :  (c) Christian Maeder and Uni Bremen 2003-2005
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  maeder@tzi.de
Stability   :  experimental
Portability :  portable

abstract syntax for HasCASL,
   more liberal than Concrete-Syntax.txt,
   annotations are almost as for CASL

-}

module HasCASL.As where

import Common.Id
import Common.Keywords
import Common.AS_Annotation 
import HasCASL.HToken

{-! for VarDecl derive: UpPos !-}

-- * abstract syntax entities with small utility functions

-- | annotated basic items
data BasicSpec = BasicSpec [Annoted BasicItem]
                  deriving Show

-- | the possible items
data BasicItem = SigItems SigItems
               | ProgItems [Annoted ProgEq] Range
               -- pos "program", dots
               | ClassItems Instance [Annoted ClassItem] Range
               -- pos "class", ";"s
               | GenVarItems [GenVarDecl] Range
               -- pos "var", ";"s
               | FreeDatatype [Annoted DatatypeDecl] Range
               -- pos "free", "type", ";"s
               | GenItems [Annoted SigItems] Range 
               -- pos "generated" "{", ";"s, "}"
               -- or "generated" "type" ";"s
               | AxiomItems [GenVarDecl] [Annoted Term] Range
               -- pos "forall" (if GenVarDecl not empty), dots 
               | Internal [Annoted BasicItem] Range
               -- pos "internal" "{", ";"s, "}"
                 deriving Show

-- | signature items are types or functions
data SigItems = TypeItems Instance [Annoted TypeItem] Range -- including sort
              -- pos "type", ";"s
              | OpItems OpBrand [Annoted OpItem] Range
              -- pos "op", ";"s
                 deriving Show

-- | indicator for predicate, operation or function
data OpBrand = Pred | Op | Fun deriving (Eq, Ord) 

-- | test if the function was declared as predicate
isPred :: OpBrand -> Bool
isPred b = case b of Pred -> True
                     _ -> False

instance Show OpBrand where
    show b = case b of
        Pred -> predS
        Op -> opS
        Fun -> functS

-- | indicator in 'ClassItems' and 'TypeItems'
data Instance = Instance | Plain

instance Show Instance where
    show i = case i of
        Instance -> instanceS
        Plain -> ""

-- | a class item
data ClassItem = ClassItem ClassDecl [Annoted BasicItem] Range 
                 -- pos "{", ";"s "}"
                 deriving Show

-- | declaring class identifiers
data ClassDecl = ClassDecl [ClassId] Kind Range
               -- pos ","s
                 deriving Show

-- | co- or contra- variance indicator                          
data Variance = CoVar | ContraVar | InVar deriving (Eq, Ord)

instance Show Variance where
    show v = case v of 
        CoVar -> plusS
        ContraVar -> minusS
        InVar -> ""

-- | (higher) kinds
data AnyKind a = ClassKind a
               | FunKind Variance (AnyKind a) (AnyKind a) Range     
             -- pos "+" or "-" 
            deriving (Show, Eq, Ord)

type Kind = AnyKind ClassId
type RawKind = AnyKind ()

-- | the possible type items 
data TypeItem  = TypeDecl [TypePattern] Kind Range
               -- pos ","s
               | SubtypeDecl [TypePattern] Type Range
               -- pos ","s, "<"
               | IsoDecl [TypePattern] Range
               -- pos "="s
               | SubtypeDefn TypePattern Vars Type (Annoted Term) Range
               -- pos "=", "{", ":", dot, "}"
               | AliasType TypePattern (Maybe Kind) TypeScheme Range
               -- pos ":="
               | Datatype DatatypeDecl
                 deriving Show

-- | a tuple pattern for 'SubtypeDefn' 
data Vars = Var Var | VarTuple [Vars] Range deriving (Show, Eq)

-- | the lhs of most type items 
data TypePattern = TypePattern TypeId [TypeArg] Range
                 -- pos "("s, ")"s 
                 | TypePatternToken Token
                 | MixfixTypePattern [TypePattern]
                 | BracketTypePattern BracketKind [TypePattern] Range
                 -- pos brackets (no parenthesis)
                 | TypePatternArg TypeArg Range
                 -- pos "(", ")"
                   deriving Show

-- | types based on variable or constructor names and applications
data Type = TypeName TypeId RawKind Int  
          -- Int == 0 means constructor, negative are bound variables
          | TypeAppl Type Type
          | ExpandedType Type Type    -- an alias type with its expansion
          -- only the following variants are parsed
          | KindedType Type Kind Range
          -- pos ":"
          | TypeToken Token
          | BracketType BracketKind [Type] Range
          -- pos "," (between type arguments)
          | MixfixType [Type] 
            deriving Show

-- | change the type within a scheme
mapTypeOfScheme :: (Type -> Type) -> TypeScheme -> TypeScheme
mapTypeOfScheme f (TypeScheme args t ps) =
    TypeScheme args (f t) ps

{- | a type with bound type variables. The bound variables within the
scheme should have negative numbers in the order given by the type
argument list. The type arguments store proper kinds (including
downsets) whereas the kind within the type names are only raw
kinds. -}
data TypeScheme = TypeScheme [TypeArg] Type Range
                -- pos "forall", ";"s,  dot (singleton list)
                -- pos "\" "("s, ")"s, dot for type aliases
                  deriving Show

-- | indicator for partial or total functions
data Partiality = Partial | Total deriving (Eq, Ord)

instance Show Partiality where
    show p = case p of
        Partial -> quMark
        Total -> exMark

-- | function declarations or definitions
data OpItem = OpDecl [OpId] TypeScheme [OpAttr] Range
               -- pos ","s, ":", ","s, "assoc", "comm", "idem", "unit"
            | OpDefn OpId [[VarDecl]] TypeScheme Partiality Term Range
               -- pos "("s, ";"s, ")"s, ":" or ":?", "="
              deriving Show

-- | attributes without arguments for binary functions 
data BinOpAttr = Assoc | Comm | Idem deriving Eq

instance Show BinOpAttr where
    show a = case a of
        Assoc -> assocS
        Comm -> commS
        Idem -> idemS

-- | possible function attributes (including a term as a unit element)
data OpAttr = BinOpAttr BinOpAttr Range 
            | UnitOpAttr Term Range deriving (Show, Eq)

-- | a polymorphic data type declaration with a deriving clause
data DatatypeDecl = DatatypeDecl 
                    TypePattern 
                    Kind
                    [Annoted Alternative] 
                    [ClassId]
                    Range 
                     -- pos "::=", "|"s, "deriving"
                     deriving Show

{- | Alternatives are subtypes or a constructor with a list of
(curried) tuples as arguments. Only the components of the first tuple
can be addressed by the places of the mixfix constructor. -}
data Alternative = Constructor UninstOpId [[Component]] Partiality Range
                   -- pos: "("s, ";"s, ")"s, "?"
                 | Subtype [Type] Range
                   -- pos: "type", ","s
                   deriving Show

{- | A component is a type with on optional (only pre- or postfix) 
   selector function. -}
data Component = Selector UninstOpId Partiality Type SeparatorKind Range 
                -- pos ",", ":" or ":?"
                | NoSelector Type
                  deriving Show

-- | the possible quantifiers
data Quantifier = Universal | Existential | Unique
                  deriving (Eq, Ord)

instance Show Quantifier where
    show q = case q of
        Universal -> forallS
        Existential -> existsS 
        Unique -> existsS ++ exMark

-- | the possibly type annotations of terms
data TypeQual = OfType | AsType | InType | Inferred deriving (Eq, Ord)

instance Show TypeQual where
    show q = case q of
        OfType -> colonS
        AsType -> asS
        InType -> inS
        Inferred -> colonS

-- | an indicator of (otherwise equivalent) let or where equations
data LetBrand = Let | Where | Program deriving (Show, Eq, Ord)

-- | the possible kinds of brackets (that should match when parsed) 
data BracketKind = Parens | Squares | Braces deriving (Show, Eq, Ord)

-- | the brackets as strings for printing
getBrackets :: BracketKind -> (String, String)
getBrackets b = case b of
                       Parens -> ("(", ")")
                       Squares -> ("[", "]")
                       Braces -> ("{", "}")

{- | The possible terms and patterns. Formulas are also kept as terms. Local variables and constants are kept separatetly. The variant 'ResolvedMixTerm' is an intermediate representation for type checking only. -}
data Term = QualVar VarDecl
          -- pos "(", "var", ":", ")"
          | QualOp OpBrand InstOpId TypeScheme Range
          -- pos "(", "op", ":", ")" 
          | ApplTerm Term Term Range  -- analysed
          -- pos?
          | TupleTerm [Term] Range    -- special application
          -- pos "(", ","s, ")"
          | TypedTerm Term TypeQual Type Range
          -- pos ":", "as" or "in"
          | AsPattern VarDecl Pattern Range          
          -- pos "@"
          | QuantifiedTerm Quantifier [GenVarDecl] Term Range
          -- pos quantifier, ";"s, dot
          -- only "forall" may have a TypeVarDecl
          | LambdaTerm [Pattern] Partiality Term Range
          -- pos "\", dot (plus "!") 
          | CaseTerm Term [ProgEq] Range
          -- pos "case", "of", "|"s 
          | LetTerm LetBrand [ProgEq] Term Range
          -- pos "where", ";"s
          | ResolvedMixTerm Id [Term] Range
          | TermToken Token
          | MixTypeTerm TypeQual Type Range
          | MixfixTerm [Term]
          | BracketTerm BracketKind [Term] Range
          -- pos brackets, ","s 
            deriving (Show, Eq, Ord)

-- | patterns are terms constructed by the first six variants
type Pattern = Term

-- | an equation or a case as pair of a pattern and a term 
data ProgEq = ProgEq Pattern Term Range deriving (Show, Eq, Ord)
            -- pos "=" (or "->" following case-of)


{- | an indicator if variables were separated by commas or by separate
declarations -}
data SeparatorKind = Comma | Other deriving Show

-- | a variable with its type
data VarDecl = VarDecl Var Type SeparatorKind Range deriving Show
               -- pos "," or ":" 

-- | the kind of a type variable (or a type argument in schemes) 
data VarKind = VarKind Kind | Downset Type | MissingKind 
               deriving (Show, Eq, Ord)

-- | a (simple) type variable with its kind (or supertype)
data TypeArg = TypeArg TypeId Variance VarKind RawKind Int SeparatorKind Range
               -- pos "," or ":", "+" or "-"
               deriving Show

-- | a value or type variable
data GenVarDecl = GenVarDecl VarDecl
                | GenTypeVarDecl TypeArg
                  deriving (Show, Eq, Ord)

-- | a polymorphic function identifier with type arguments 
data OpId = OpId UninstOpId [TypeArg] Range deriving (Show, Eq, Ord)
     -- pos "[", ";"s, "]" 

-- | an instantiated function identifiers 
data InstOpId = InstOpId UninstOpId [Type] Range deriving (Show, Eq, Ord)

-- * synonyms for identifiers

{- | type variables are expected to be simple whereas type constructors may be 
     mixfix- and compound identifiers -} 
type TypeId = Id
type UninstOpId = Id

{- | variables are non-compound identifiers but may be mixfix if their
types permit -}
type Var = Id

-- | class identifier are simple but may be compound (like CASL sorts)
type ClassId = Id

-- * symbol data types
-- | symbols 
data SymbItems = SymbItems SymbKind [Symb] [Annotation] Range 
                  -- pos: kind, commas
                  deriving (Show, Eq)

-- | mapped symbols 
data SymbMapItems = SymbMapItems SymbKind [SymbOrMap] [Annotation] Range
                      -- pos: kind commas
                      deriving (Show, Eq)

-- | kind of symbols
data SymbKind = Implicit | SK_type | SK_sort | SK_fun | SK_op | SK_pred 
              | SK_class
                 deriving (Show, Eq, Ord)

-- | type annotated symbols
data Symb = Symb Id (Maybe SymbType) Range 
            -- pos: colon (or empty)
            deriving (Show, Eq)

-- | type for symbols
data SymbType = SymbType TypeScheme
            deriving (Show, Eq)

-- | mapped symbol
data SymbOrMap = SymbOrMap Symb (Maybe Symb) Range
                   -- pos: "|->" (or empty)
                   deriving (Show, Eq)

-- ----------------------------------------------------------------------------
-- equality instances ignoring positions
-- ----------------------------------------------------------------------------

instance Eq Type where 
    TypeName i1 k1 v1 == TypeName i2 k2 v2 = 
        if v1 == 0 && v2 == 0 then (i1, k1) == (i2, k2)
        else (v1, k1) == (v2, k2)
    TypeAppl f1 a1 == TypeAppl f2 a2 = (f1, a1) == (f2, a2)
    TypeToken t1 == TypeToken t2 = t1 == t2
    BracketType b1 l1 _ == BracketType b2 l2 _ = (b1, l1) == (b2, l2)
    KindedType t1 k1 _ == KindedType t2 k2 _ = (t1, k1) == (t2, k2)
    MixfixType l1 == MixfixType l2 = l1 == l2
    ExpandedType _ t1 == t2 = t1 == t2
    t1 == ExpandedType _ t2 = t1 == t2
    _ == _ = False

instance Ord Type where
    TypeName i1 k1 v1 <= TypeName i2 k2 v2 = 
        if v1 == 0 && v2 == 0 then (i1, k1) <= (i2, k2)
        else (v1, k1) <= (v2, k2)
    TypeAppl f1 a1 <= TypeAppl f2 a2 = (f1, a1) <= (f2, a2)
    TypeToken t1 <= TypeToken t2 = t1 <= t2
    BracketType b1 l1 _ <= BracketType b2 l2 _ = (b1, l1) <= (b2, l2)
    KindedType t1 k1 _ <= KindedType t2 k2 _ = (t1, k1) <= (t2, k2)
    MixfixType l1 <= MixfixType l2 = l1 <= l2
    ExpandedType _ t1 <= t2 = t1 <= t2
    t1 <= ExpandedType _ t2 = t1 <= t2
    TypeName _ _ _ <= _ = True
    _ <= TypeName _ _ _ = False
    TypeAppl _ _ <= _ = True 
    _ <= TypeAppl _ _ = False
    TypeToken _ <= _ = True
    _ <= TypeToken _ = False
    BracketType _ _ _ <= _ = True
    _ <= BracketType _ _ _ = False
    KindedType _ _ _ <= _ = True
    _ <= KindedType _ _ _ = False

-- equality for disambiguation in HasCASL2Haskell
instance Eq TypeScheme where
    TypeScheme a1 t1 _ == TypeScheme a2 t2 _ = 
        (length a1, t1) == (length a2, t2)

-- order used within terms
instance Ord TypeScheme where
    TypeScheme a1 t1 _ <= TypeScheme a2 t2 _ = 
        (length a1, t1) <= (length a2, t2)

-- used within quantified formulas
instance Eq TypeArg where
    TypeArg i1 _ e1 v1 c1 _ _ == TypeArg i2 _ e2 v2 c2 _ _ = 
        (i1, e1, v1, c1) == (i2, e2, v2, c2)
instance Ord TypeArg where
    TypeArg i1 _ e1 v1 c1 _ _ <= TypeArg i2 _ e2 v2 c2 _ _ = 
        (i1, e1, v1, c1) <= (i2, e2, v2, c2)

instance Eq VarDecl where
    VarDecl v1 t1 _ _ == VarDecl v2 t2 _ _ = (v1, t1) == (v2, t2) 
instance Ord VarDecl where
    VarDecl v1 t1 _ _ <= VarDecl v2 t2 _ _ = (v1, t1) <= (v2, t2) 

instance Eq Component where 
    Selector i1 p1 t1 _ _ == Selector i2 p2 t2 _ _ =
        (i1, t1, p1) == (i2, t2, p2)
    NoSelector t1 == NoSelector t2 = t1 == t2
    _ == _ = False

-- * compute better position 

instance PosItem Type where
  getRange ty = case ty of
    TypeName i _ _ -> posOfId i
    TypeAppl t1 t2 -> posOf [t1, t2]
    ExpandedType t1 t2 -> posOf [t1, t2]
    TypeToken t -> tokPos t
    BracketType _ ts ps -> firstPos ts ps
    KindedType t _ ps -> firstPos [t] ps
    MixfixType ts -> posOf ts

instance PosItem Term where
   getRange trm = case trm of
    QualVar v -> getRange v
    QualOp _ (InstOpId i _ ps) _ qs -> firstPos [i] (ps `appRange` qs)
    ResolvedMixTerm i _ _ -> posOfId i
    ApplTerm t1 t2 ps -> firstPos [t1, t2] ps
    TupleTerm ts ps -> firstPos ts ps
    TypedTerm t _ _ ps -> firstPos [t] ps
    QuantifiedTerm _ _ t ps -> firstPos [t] ps
    LambdaTerm _ _ t ps -> firstPos [t] ps
    CaseTerm t _ ps -> firstPos [t] ps
    LetTerm _ _ t ps -> firstPos [t] ps
    TermToken t -> tokPos t
    MixTypeTerm _ t ps -> firstPos [t] ps
    MixfixTerm ts -> posOf ts
    BracketTerm _ ts ps -> firstPos ts ps
    AsPattern v _ ps -> firstPos [v] ps

instance PosItem TypePattern where
  getRange pat = case pat of
    TypePattern t _ ps -> firstPos [t] ps
    TypePatternToken t -> tokPos t
    MixfixTypePattern ts -> posOf ts
    BracketTypePattern _ ts ps -> firstPos ts ps
    TypePatternArg (TypeArg t _ _ _ _ _ _) ps -> firstPos [t] ps

