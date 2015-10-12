module CSSR.Parse.Tree where

import CSSR.CausalState.History (Moment, History)

data ParseTree = Root [ParseTreeBranch] deriving Show

data ParseTreeBranch = Branch (Moment, [ParseTreeBranch]) deriving Show

parseTree :: ParseTree
parseTree = Root []

exampleBranchArray = [
  Branch ('a', [
    Branch ('b',[
      Branch ('c',[]),
      Branch ('a',[])
    ]),
    Branch ('c',[
      Branch ('c',[]),
      Branch ('a',[])
    ])
  ]) ]

exampleParseTree = Root exampleBranchArray

-- | build takes a list of characters and generates a ParseTree
build :: [ParseTreeBranch] -> [Moment] -> [ParseTreeBranch]
-- | if we have a sparse tree and a char-sequence
build branches@(Branch(bChar, children):[])
                  chars@(char:path)                  = if (char == bChar)
                                                       then if (null path)
                                                            then branches
                                                            else [Branch(bChar, (build children path))]
                                                       else if (null path)
                                                            then Branch(char, []):branches
                                                            else build ( Branch(char,[]):branches ) chars
-- | if we have a full tree and a char-sequence
build branches@(Branch(bChar, children):siblings)
                  chars@(char:path)                  = if (char == bChar)
                                                       then if (null path)
                                                            then branches
                                                            else Branch(bChar, (build children path)):siblings
                                                       else if (null path)
                                                            then Branch(char,[]):branches
                                                             else build ( Branch(char,[]):branches ) chars
-- | if we have an empty tree
build []       (char:[])   = build [Branch(char,[])] []
build [] chars@(char:path) = build [Branch(char,[])] chars

build branches _ = branches

walk :: [ParseTreeBranch] -> Int -> [History]
walk tree@(    Branch(m,          []):[]    ) depth | depth >= 0 = [[m]]
walk tree@(    Branch(m, children:[]):[]    ) depth | depth >= 0 = map ((:) m) (walk [children] $ depth-1)
-- MISSING: a branch having many children and no siblings
walk tree@(    Branch(m,        []):siblings) depth | depth >= 0 = [m]:(walk siblings depth)
-- MISSING: a branch having one child and many siblings
walk tree@( b@(Branch(m, children)):siblings) depth | depth >= 0 = (walk [b] depth) ++ (walk siblings depth)
walk _ _ = []

getBranches :: ParseTree -> [ParseTreeBranch]
getBranches tree@(Root branches) = branches
