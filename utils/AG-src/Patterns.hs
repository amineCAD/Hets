-- do not edit; automatically generated by UU_AG
module Patterns where

import TokenDef(Pos)
-- Pattern -----------------------------------------------------
data Pattern = Alias (Pos) (String) (Pattern)
             | Constr (Pos) (String) (Patterns)
             | Product (Pos) (Patterns)
             | Underscore (Pos)
             | Var (Pos) (String)
-- Patterns ----------------------------------------------------
type Patterns = [(Pattern)]

