module Data.Looping.Tree where

import Data.STRef
import qualified Data.HashSet as HS
import qualified Data.HashMap.Strict as HM
import qualified Data.Vector as V
import Data.Vector (Vector, (!))
import Data.Vector.Mutable (MVector)
import qualified Data.Vector.Mutable as MV
import qualified Data.HashTable.ST.Cuckoo as C
import qualified Data.HashTable.Class as H
import Data.Foldable

import CSSR.Prelude
import Data.CSSR.Alphabet
import Data.Hist.Tree (HLeaf, HLeafBody, HistTree(..))
import qualified Data.Hist.Tree as Hist

import Data.CSSR.Leaf.Probabilistic (Probabilistic)
import qualified Data.CSSR.Leaf.Probabilistic as Prob

-------------------------------------------------------------------------------
-- Mutable Looping Tree ADTs
-------------------------------------------------------------------------------
data MLLeaf s = MLLeaf
  { _isLoop    :: STRef s Bool
  -- | for lack of a mutable hash set implementation
  , _histories :: C.HashTable s HLeaf Bool
  , _frequency :: MVector s Integer
  , _children :: C.HashTable s Event (MLLeaf s)
  }

data LLeaf = LLeaf
  { isLoop    :: Bool
  , histories :: HashSet HLeaf
  , frequency :: Vector Integer
  , children  :: HashMap Event LLeaf
  , parent    :: Maybe LLeaf
  }

data LoopingTree = LoopingTree
  { _terminals :: HashSet LLeaf
  , _root :: LLeaf
  }

instance Eq LLeaf where
  (LLeaf l0 h0 f0 c0 _) == (LLeaf l1 h1 f1 c1 _) =
    l0 == l1 && h0 == h1 && f0 == f1 && c0 == c1

instance Show LLeaf where
  show (LLeaf l h f c _) = "LLeaf{"++bod++"}"
    where
      bod :: String
      bod = intercalate ", "
        [ "isLoop: " ++ show l
        , "histories: " ++ show h
        , "frequency: " ++ show f
        , "children: " ++ show c]


instance Probabilistic LLeaf where
  frequency = Data.Looping.Tree.frequency

mkRoot :: Alphabet -> ST s (MLLeaf s)
mkRoot (Alphabet vec _) =
  MLLeaf <$> newSTRef False <*> H.new <*> MV.replicate (V.length vec) 0 <*> H.new


grow :: HistTree -> ST s (MLLeaf s)
grow (HistTree _ a hRoot) = do
  rt <- mkRoot a
  go [hRoot] rt
  -- let findAlternative = LoopingTree.findAlt(ltree)(_)
  return rt

  where
    go :: [HLeaf] -> MLLeaf s -> ST s ()
    go             [] lf = return ()
    go (active:queue) lf = go queue lf
      where
        isHomogeneous :: Bool
        isHomogeneous = undefined


isHomogeneous :: LLeaf -> Bool
isHomogeneous ll = foldr step True allPChilds
  where
    allPChilds :: HashSet HLeaf
    allPChilds = HS.fromList $
      HS.toList (histories ll) >>= HM.elems . view Hist.children

    step :: HLeaf -> Bool -> Bool
    step _  False = False
    step pc _     = Prob.matches ll pc

-- | === Excisability
--
-- Psuedocode from paper:
--   INPUTS: looping node, looping tree
--   COLLECT all ancestors of the looping node from the looping tree, ordered by
--           increasing depth (depth 0, or "root node," first)
--   FOR each ancestor
--     IF ancestor's distribution == looping node's distribution
--     THEN
--       the node is excisable: create loop in the tree
--       ENDFOR (ie "break")
--     ELSE do nothing
--     ENDIF
excisable :: LLeaf -> Maybe LLeaf
excisable ll = go (getAncestors ll)
  where
    go :: [LLeaf] -> Maybe LLeaf
    go [] = Nothing
    go (a:as)
      | Prob.matches ll a = Just a
      | otherwise = go as

-- | returns ancestors in order of how they should be processed
getAncestors :: LLeaf -> [LLeaf]
getAncestors ll = go (Just ll) []
  where
    go :: Maybe LLeaf -> [LLeaf] -> [LLeaf]
    go  Nothing ancestors = ancestors
    go (Just w) ancestors = go (parent w) (w:ancestors)

--  while (activeQueue.nonEmpty) {
--    val active:MLLeaf = activeQueue.remove(0)
--    val isHomogeneous:Boolean = active.histories.forall{ LoopingTree.nextHomogeneous(tree) }
--
--       if (isHomogeneous) {
--         debug("we've hit our base case")
--       } else {
--
--         val nextChildren:Map[Char, LoopingTree.Node] = active.histories
--           .flatMap { _.children }
--           .groupBy{ _.observation }
--           .map { case (c, pleaves) => {
--             val lleaf:MLLeaf = new MLLeaf(c + active.observed, pleaves, Option(active))
--             val alternative:Option[LoopingTree.AltNode] = findAlternative(lleaf)
--             c -> alternative.toRight(lleaf)
--           } }
--
--         active.children ++= nextChildren
--         // Now that active has children, it cannot be considered a terminal node. Thus, we elide the active node:
--         ltree.terminals = ltree.terminals ++ LoopingTree.leafChildren(nextChildren).toSet[MLLeaf] - active
--         // FIXME: how do edge-sets handle the removal of an active node? Also, are they considered terminal?
--         activeQueue ++= LoopingTree.leafChildren(nextChildren)
--       }
--     }
--
--     ltree
--   }