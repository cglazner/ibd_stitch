--------------------------------------------------------------------------
-- |
-- Module               : Data.Parition
-- Copyright            : (c) Luke Palmer, 2013
-- License              : BSD3
--
-- Maintainer           : Luke Palmer <lrpalmer@gmail.com>
-- Stability            : experimental
-- Portability          : portable
--
-- Disjoint set data structure -- @IntPartition@ maintains a collection of
-- disjoint sets of type @a@, with the ability to find which set a particular
-- item belongs to and the ability to merge any two such sets into one.
---------------------------------------------------------------------------

module MyPart
    ( IntPartition, discrete, empty, fromSets, nontrivialSets, join, find, rep )
 where

import qualified Data.IntMap as Map
import qualified Data.IntSet as Set
import Data.Maybe (fromMaybe)

-- | A Partition of @a@: represents a collection of disjoint sets of @a@ whose
-- union includes every element of @a@.  Semantics: @[[IntPartition]] = P(P(a))@
-- where @P@ is the power set operation.
data IntPartition 
    = IntPartition { forwardMap :: Map.IntMap Int, backwardMap :: Map.IntMap (Set.IntSet) }
    deriving (Eq, Ord)  -- Since the representative is always the least element,
                        -- we have a canonical representation and Eq is meaningful.
                        -- Ord may not mean anything, but at least there some 
                        -- computable total ordering on Partitions, and that is helpful
                        -- sometimes.

instance Show (IntPartition) where
    show p = "fromSets " ++ show (nontrivialSets p)

-- | A partition in which every element of @a@ is in its own set.  Semantics:
-- @[[discrete]] = { { x } | x in a }@
discrete :: IntPartition
discrete = IntPartition Map.empty Map.empty

-- | Synonym for @discrete@.
empty :: IntPartition
empty = discrete

-- | Takes a list of disjoint sets and constructs a partition containing those sets,
-- with every remaining element being given its own set.
fromSets :: [Set.IntSet] -> IntPartition
fromSets sets = IntPartition { 
        forwardMap = Map.fromList [ (x, Set.findMin s) | s <- sets, x <- Set.toList s ],
        backwardMap = Map.fromList [ (Set.findMin s, s) | s <- sets ]
    }

-- | Returns a list of all nontrivial sets (sets with more than one element) in the 
-- partition.
nontrivialSets :: IntPartition -> [Set.IntSet]
nontrivialSets = Map.elems . backwardMap

-- | @join x y@ merges the two sets containing @x@ and @y@ into a single set.  Semantics:
-- @[[join x y p]] = (p \`minus\` find x \`minus\` find y) \`union\` { find x \`union\` find y }@
join :: Int -> Int -> IntPartition -> IntPartition
join x y p = case compare x' y' of
                 LT -> go x' y'
                 EQ -> p
                 GT -> go y' x'
    where
    x' = rep p x
    y' = rep p y

    go into other = IntPartition { 
                        forwardMap = compose [ Map.insert o into | o <- Set.toList otherSrc ] (forwardMap p),
                        backwardMap = Map.insert into (Set.union (repFind p into) otherSrc) 
                                    . Map.delete other
                                    $ backwardMap p
                    }
        where
        otherSrc = repFind p other

-- | @find p x@ finds the set that the element @x@ is associated with.  Semantics: 
-- @[[find p x]] = the unique s in p such that x in s@.
find :: IntPartition -> Int -> Set.IntSet
find p = repFind p . rep p

-- | @rep p x@ finds the minimum element in the set containing @x@.
rep :: IntPartition -> Int -> Int
rep p x = fromMaybe x (Map.lookup x (forwardMap p))

-- Find the set that x is in given that x is already a representative element.
repFind :: IntPartition -> Int -> Set.IntSet
repFind p x = fromMaybe (Set.singleton x) (Map.lookup x (backwardMap p))

compose :: [a -> a] -> a -> a
compose = foldr (.) id
