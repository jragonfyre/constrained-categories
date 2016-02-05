-- |
-- Module      :  Control.Category.Constrained.Reified
-- Copyright   :  (c) 2016 Justus Sagemüller
-- License     :  GPL v3 (see COPYING)
-- Maintainer  :  (@) sagemueller $ geo.uni-koeln.de
-- 
-- 
-- GADTs that mirror the class hierarchy from 'Category' to (at the moment) 'Cartesian',
-- reifying all the available “free” composition operations.
-- 
-- These can be used as a “trivial base case“ for all kinds of categories:
-- it turns out these basic operations are often not so trivial to implement,
-- or only possible with stronger constraints than you'd like. For instance,
-- the category of affine mappings can only be implemented directly as a
-- category on /vector spaces/, because the identity mapping has /zero/ constant
-- offset.
-- 
-- By leaving the free compositions reified to runtime syntax trees, this problem
-- can be avoided. In other applications, you may not /need/ these cases,
-- but can still benefit from them for optimisation (composition with 'id' is
-- always trivial, and so on).

{-# LANGUAGE GADTs                 #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ConstraintKinds       #-}
{-# LANGUAGE UnicodeSyntax         #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE CPP                   #-}
{-# LANGUAGE PatternSynonyms       #-}
{-# LANGUAGE ViewPatterns          #-}

module Control.Category.Constrained.Reified (
      -- * Reified versions of the category classes
         ReCategory (..)
       , ReCartesian (..)
       , ReMorphism (..)
       , RePreArrow (..)
       , ReWellPointed (..)
      -- * Auxiliary
       , EnhancedCat'
       ) where


import Prelude ()
import GHC.Exts (Constraint)

import Control.Category.Constrained.Prelude
import Control.Arrow.Constrained

import Data.Tagged


data ObjectWitness k α where
  IsObject :: Object k α => ObjectWitness k α

domObjWitness :: (Category k, Object k α) => k α β -> ObjectWitness k α
domObjWitness _ = IsObject
codomObjWitness :: (Category k, Object k β) => k α β -> ObjectWitness k β
codomObjWitness _ = IsObject

withObjWitness :: ObjectWitness k γ -> (ObjectWitness k γ -> k α β) -> k α β
withObjWitness w f = f w

data ObjPairWitness k α β where
  AreObjects :: ObjectPair k α β => ObjPairWitness k α β
data UnitObjWitness k u where
  IsUnitObj :: UnitObjWitness k (UnitObject k)





infixr 1 :>>>

data ReCategory (k :: * -> * -> *) (α :: *) (β :: *) where
    ReCategory :: k α β -> ReCategory k α β
    Id :: Object k α => ReCategory k α α
    (:>>>) :: Object k β
         => ReCategory k α β -> ReCategory k β γ -> ReCategory k α γ

instance Category k => Category (ReCategory k) where
  type Object (ReCategory k) α = Object k α
  id = Id
  Id . g = g
  f . Id = f
  f . g = g :>>> f

class CRCategory k where
  match_id :: k α β -> Maybe (ReCategory k α β)
  match_compose :: k α β -> Maybe (ReCategory k α β)

instance CRCategory (ReCategory k) where
  match_id Id = Just Id
  match_id _ = Nothing
  match_compose (f:>>>g) = Just $ ReCategory f :>>> ReCategory g
  match_compose _ = Nothing

pattern Id' <- (match_id -> Just Id)
pattern f:<<<g <- (match_compose -> Just (ReCategory g :>>> ReCategory f))
  
instance HasAgent k => HasAgent (ReCategory k) where
  type AgentVal (ReCategory k) α ω = GenericAgent (ReCategory k) α ω
  alg = genericAlg
  ($~) = genericAgentMap
  

#define REENHANCE(ct)                                                       \
instance Category k => EnhancedCat ((ct) k) k where { arr = arr' };          \
instance Category k => EnhancedCat' ((ct) k) k where {                        \
  arr' = (ct);                                                                 \
  arr'Object IsObject = IsObject }


REENHANCE(ReCategory)

data ReCartesian (k :: * -> * -> *) (α :: *) (β :: *) where
    ReCartesian :: k α β -> ReCartesian k α β
    ReCartesianCat :: ReCategory (ReCartesian k) α β -> ReCartesian k α β
    Swap :: (ObjectPair k α β, ObjectPair k β α)
                => ReCartesian k (α,β) (β,α)
    AttachUnit :: (Object k α, UnitObject k ~ u, ObjectPair k α u)
                => ReCartesian k α (α,u)
    DetachUnit :: (Object k α, UnitObject k ~ u, ObjectPair k α u)
                => ReCartesian k (α,u) α
    Regroup :: ( ObjectPair k α β, ObjectPair k β γ
                           , ObjectPair k α (β,γ), ObjectPair k (α,β) γ )
                => ReCartesian k (α,(β,γ)) ((α,β),γ)
    Regroup' :: ( ObjectPair k α β, ObjectPair k β γ
                            , ObjectPair k α (β,γ), ObjectPair k (α,β) γ )
                => ReCartesian k ((α,β),γ) (α,(β,γ))

instance Category k => Category (ReCartesian k) where
  type Object (ReCartesian k) a = Object k a
  
  id = ReCartesianCat id
  
  ReCartesianCat f . ReCartesianCat g = ReCartesianCat $ f . g
  ReCartesianCat Id . g = g
  f . ReCartesianCat Id = f
  Swap . Swap = id
  Regroup . Regroup' = id
  Regroup' . Regroup = id
  ReCartesianCat f . g = ReCartesianCat $ f . ReCategory g
  f . ReCartesianCat g = ReCartesianCat $ ReCategory f . g
  f . g = ReCartesianCat $ ReCategory f . ReCategory g

instance Cartesian k => Cartesian (ReCartesian k) where
  type PairObjects (ReCartesian k) α β = PairObjects k α β
  type UnitObject (ReCartesian k) = UnitObject k
  swap = Swap
  attachUnit = AttachUnit
  detachUnit = DetachUnit
  regroup = Regroup
  regroup' = Regroup'
  
instance CRCategory (ReCartesian k) where
  match_id (ReCartesianCat Id) = Just Id
  match_id _ = Nothing
  match_compose (ReCartesianCat (f:>>>g)) = Just $ f :>>> g
  match_compose _ = Nothing
  
instance HasAgent k => HasAgent (ReCartesian k) where
  type AgentVal (ReCartesian k) α ω = GenericAgent (ReCartesian k) α ω
  alg = genericAlg
  ($~) = genericAgentMap
  
  
REENHANCE(ReCartesian)


infixr 3 :***

data ReMorphism (k :: * -> * -> *) (α :: *) (β :: *) where
    ReMorphism :: k α β -> ReMorphism k α β
    ReMorphismCart :: ReCartesian (ReMorphism k) α β -> ReMorphism k α β
    (:***) :: (ObjectPair k α γ, ObjectPair k β δ)
              => ReMorphism k α β -> ReMorphism k γ δ -> ReMorphism k (α,γ) (β,δ)

instance Category k => Category (ReMorphism k) where
  type Object (ReMorphism k) a = Object k a
  
  id = ReMorphismCart id
  
  ReMorphismCart f . ReMorphismCart g = ReMorphismCart $ f . g
  ReMorphismCart (ReCartesianCat Id) . g = g
  f . ReMorphismCart (ReCartesianCat Id) = f
  (f:***g) . (h:***i) = f.h :*** g.i
  f . g = ReMorphismCart $ ReCartesian f . ReCartesian g

instance Cartesian k => Cartesian (ReMorphism k) where
  type PairObjects (ReMorphism k) α β = PairObjects k α β
  type UnitObject (ReMorphism k) = UnitObject k
  swap = ReMorphismCart swap
  attachUnit = ReMorphismCart attachUnit
  detachUnit = ReMorphismCart detachUnit
  regroup = ReMorphismCart regroup
  regroup' = ReMorphismCart regroup'
  
instance Morphism k => Morphism (ReMorphism k) where
  (***) = (:***)

instance HasAgent k => HasAgent (ReMorphism k) where
  type AgentVal (ReMorphism k) α ω = GenericAgent (ReMorphism k) α ω
  alg = genericAlg
  ($~) = genericAgentMap

REENHANCE(ReMorphism)


data RePreArrow (k :: * -> * -> *) (α :: *) (β :: *) where
    RePreArrow :: k α β -> RePreArrow k α β
    RePreArrowMorph :: ReMorphism (RePreArrow k) α β -> RePreArrow k α β
    (:&&&) :: (Object k α, ObjectPair k β γ)
            => RePreArrow k α β -> RePreArrow k α γ -> RePreArrow k α (β,γ)
    Terminal :: Object k α => RePreArrow k α (UnitObject k)
    Fst :: ObjectPair k α β => RePreArrow k (α,β) α
    Snd :: ObjectPair k α β => RePreArrow k (α,β) β

instance Category k => Category (RePreArrow k) where
  type Object (RePreArrow k) a = Object k a
  
  id = RePreArrowMorph id
  
  Terminal . _ = Terminal
  Fst . (f:&&&_) = f
  Snd . (_:&&&g) = g
  Fst . RePreArrowMorph (f:***_) = RePreArrowMorph $ f . ReMorphism Fst
  Snd . RePreArrowMorph (_:***g) = RePreArrowMorph $ g . ReMorphism Snd
  RePreArrowMorph f . RePreArrowMorph g = RePreArrowMorph $ f . g
  RePreArrowMorph (ReMorphismCart (ReCartesianCat Id)) . g = g
  f . RePreArrowMorph (ReMorphismCart (ReCartesianCat Id)) = f
  f . g = RePreArrowMorph $ ReMorphism f . ReMorphism g

instance Cartesian k => Cartesian (RePreArrow k) where
  type PairObjects (RePreArrow k) α β = PairObjects k α β
  type UnitObject (RePreArrow k) = UnitObject k
  swap = RePreArrowMorph swap
  attachUnit = RePreArrowMorph attachUnit
  detachUnit = RePreArrowMorph detachUnit
  regroup = RePreArrowMorph regroup
  regroup' = RePreArrowMorph regroup'

instance Morphism k => Morphism (RePreArrow k) where
  RePreArrowMorph f *** RePreArrowMorph g = RePreArrowMorph $ f *** g
  RePreArrowMorph f *** g = RePreArrowMorph $ f *** ReMorphism g
  f *** RePreArrowMorph g = RePreArrowMorph $ ReMorphism f *** g
  f *** g = RePreArrowMorph $ ReMorphism f *** ReMorphism g
  
instance PreArrow k => PreArrow (RePreArrow k) where
  f &&& g = f :&&& g
  terminal = Terminal
  fst = Fst
  snd = Snd


REENHANCE(RePreArrow)



data ReWellPointed (k :: * -> * -> *) (α :: *) (β :: *) where
    ReWellPointed :: k α β -> ReWellPointed k α β
    ReWellPointedArr' :: RePreArrow (ReWellPointed k) α β -> ReWellPointed k α β
    Const :: (Object k ν, ObjectPoint k α) => α -> ReWellPointed k ν α

instance Category k => Category (ReWellPointed k) where
  type Object (ReWellPointed k) a = Object k a
  
  id = ReWellPointedArr' id
  
  Const α . _ = Const α
  ReWellPointedArr' f . ReWellPointedArr' g = ReWellPointedArr' $ f . g
  ReWellPointedArr' (RePreArrowMorph (ReMorphismCart (ReCartesianCat Id))) . g = g
  f . ReWellPointedArr' (RePreArrowMorph (ReMorphismCart (ReCartesianCat Id))) = f
  f . g = ReWellPointedArr' $ RePreArrow f . RePreArrow g

instance Cartesian k => Cartesian (ReWellPointed k) where
  type PairObjects (ReWellPointed k) α β = PairObjects k α β
  type UnitObject (ReWellPointed k) = UnitObject k
  swap = ReWellPointedArr' swap
  attachUnit = ReWellPointedArr' attachUnit
  detachUnit = ReWellPointedArr' detachUnit
  regroup = ReWellPointedArr' regroup
  regroup' = ReWellPointedArr' regroup'

instance Morphism k => Morphism (ReWellPointed k) where
  ReWellPointedArr' f *** ReWellPointedArr' g = ReWellPointedArr' $ f *** g
  ReWellPointedArr' f *** g = ReWellPointedArr' $ f *** RePreArrow g
  f *** ReWellPointedArr' g = ReWellPointedArr' $ RePreArrow f *** g
  f *** g = ReWellPointedArr' $ RePreArrow f *** RePreArrow g

instance PreArrow k => PreArrow (ReWellPointed k) where
  ReWellPointedArr' f &&& ReWellPointedArr' g = ReWellPointedArr' $ f &&& g
  ReWellPointedArr' f &&& g = ReWellPointedArr' $ f &&& RePreArrow g
  f &&& ReWellPointedArr' g = ReWellPointedArr' $ RePreArrow f &&& g
  f &&& g = ReWellPointedArr' $ RePreArrow f &&& RePreArrow g
  terminal = ReWellPointedArr' terminal
  fst = ReWellPointedArr' fst
  snd = ReWellPointedArr' snd

instance WellPointed k => WellPointed (ReWellPointed k) where
  type PointObject (ReWellPointed k) α = PointObject k α
  const = Const
  unit = u
   where u :: ∀ k . WellPointed k => CatTagged (ReWellPointed k) (UnitObject k)
         u = Tagged u' where Tagged u' = unit :: CatTagged k (UnitObject k)
  

REENHANCE(ReWellPointed)




-- | @'EnhancedCat'' a k@ means that @k@ is a subcategory of @a@, so @k@-arrows also
--   work as @a@-arrows. This requires of course that all objects of @k@ are also
--   objects of @a@.
class (EnhancedCat a k) => EnhancedCat' a k where
  arr' :: (Object k b, Object k c)
         => k b c -> a b c
  arr'Object :: ObjectWitness k α -> ObjectWitness a α
class (EnhancedCat' a k, Cartesian a, Cartesian k) => EnhancedCat'P a k where
  arr'ObjPair :: ObjPairWitness k α β -> ObjPairWitness a α β
  arr'UnitObj :: UnitObjWitness k u -> UnitObjWitness a u
instance (Category k) => EnhancedCat' k k where
  arr' = id
  arr'Object IsObject = IsObject

