{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE DeriveGeneric #-}

module Data.Hist.Tree where

import Data.List
import qualified Data.HashMap.Strict as HM
import Data.Vector ((!))
import qualified Data.Vector as V
import Lens.Micro.Internal
import GHC.Generics (Generic)
import Data.Hashable

import Data.CSSR.Leaf.Probabilistic
import Data.Parse.Tree (ParseTree(..), PLeaf(..), PLeafBody(..))
import qualified Data.Parse.Tree as Parse
import Data.CSSR.Alphabet
import CSSR.Prelude


-------------------------------------------------------------------------------
-- Hist Tree ADTs
-------------------------------------------------------------------------------
data HistTree = HistTree
  { _depth :: Int
  , _alphabet :: Alphabet
  , _root :: HLeaf
  } deriving (Eq, Generic)

data HLeaf = HLeaf
  { _body :: HLeafBody
  , _children :: HashMap Event HLeaf
  } deriving (Eq, Generic)

data HLeafBody = HLeafBody
  { _obs       :: Vector Event
  , _frequency :: Vector Integer
  } deriving (Eq, Generic)

instance Show HistTree where
  show (HistTree d a r) = "HistTree {depth " ++ show d ++ ", "++ show a ++"}\n  root:" ++ show r

instance Show HLeaf where
  show = go 1 " "
    where
      indent :: Int -> String
      indent d = replicate (5 * d) ' '

      showLeaf :: Int -> Event -> HLeafBody -> String
      showLeaf d e b = "\n" ++ indent d ++ show e ++"->HLeaf{" ++ show b

      go :: Int -> Event -> HLeaf -> String
      go d e (HLeaf b cs)
        | length cs == 0 = showLeaf d e b ++ ", no children}"
        | otherwise = showLeaf d e b ++ "}\n"
                      ++ indent (d + 1) ++ "children:"
                      ++ (intercalate "\n" . map (uncurry (go (d+1))) . HM.toList $ cs)

instance Show HLeafBody where
  show (HLeafBody o c) =
    "obs: " ++ show o ++ ", freq: " ++ show c

instance Hashable HLeafBody
instance Hashable HLeaf
instance Hashable HistTree

makeLenses ''HLeafBody
makeLenses ''HLeaf
makeLenses ''HistTree


instance Probabilistic HLeaf where
  frequency = view (body . Data.Hist.Tree.frequency)


-------------------------------------------------------------------------------
-- Convert ParseTree to HistTree
-------------------------------------------------------------------------------

convert :: ParseTree -> Alphabet -> HistTree
convert (ParseTree d rt) alpha = HistTree d alpha (go d rt)
  where
    go :: Int -> PLeaf -> HLeaf
    go 0 lf = mkHLeaf lf mempty
    go d lf = mkHLeaf lf $ HM.map (go (d-1)) (view Parse.children lf)

    mkHLeaf :: PLeaf -> HashMap Event HLeaf -> HLeaf
    mkHLeaf (PLeaf (PLeafBody o _ _) cs) = HLeaf (mkBody o cs)

    mkBody :: Vector Event -> HashMap Event PLeaf -> HLeafBody
    mkBody o cs = HLeafBody o (mkFrequency cs alpha)

    mkFrequency :: HashMap Event PLeaf -> Alphabet -> Vector Integer
    mkFrequency cs (Alphabet vec _) =
      V.map (\s -> (maybe 0 getCounts . HM.lookup s) cs) vec

    getCounts :: PLeaf -> Integer
    getCounts = view (Parse.body . Parse.count)


-------------------------------------------------------------------------------
-- CSSR Properties
-------------------------------------------------------------------------------
--
-- Excisability:
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
--   ENDFOR

-------------------------------------------------------------------------------
-- Lenses for Hist Trees
-------------------------------------------------------------------------------
type instance Index HLeaf = Vector Event
type instance IxValue HLeaf = HLeaf

-- Example: set (ix (V.fromList "9") . body . count)  50000 mkRoot
--
instance Ixed HLeaf where
  ix :: Vector Event -> Traversal' HLeaf (IxValue HLeaf)
  ix histories = go (V.length histories - 1)
    where
      go 0 f p = f p
      go d f p@(HLeaf bod childs)
        | d <= 0 = f p
        | otherwise =
          case HM.lookup c childs of
            Nothing -> pure p
            Just child -> goAgain <$> go (d-1) f child
        where
          c :: Event
          c = histories V.! d

          goAgain :: HLeaf -> HLeaf
          goAgain child' = HLeaf bod (HM.insert c child' childs)

navigate :: HistTree -> Vector Event -> Maybe HLeaf
navigate tree history
  | V.null history = Just (view root tree)
  | otherwise = go (V.length history) (view root tree)
  where
    go :: Int -> HLeaf -> Maybe HLeaf
    go 0 lf = Just lf
    go d (HLeaf bod childs) =
      let nxt = d - 1
      in case HM.lookup (history ! nxt) childs of
        Just child -> go nxt child
        _ -> Nothing




