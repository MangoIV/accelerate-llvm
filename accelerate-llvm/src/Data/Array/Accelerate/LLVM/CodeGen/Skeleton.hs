{-# LANGUAGE GADTs               #-}
{-# LANGUAGE RecordWildCards     #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators       #-}
{-# OPTIONS_HADDOCK hide #-}
-- |
-- Module      : Data.Array.Accelerate.LLVM.CodeGen.Skeleton
-- Copyright   : [2015..2019] The Accelerate Team
-- License     : BSD3
--
-- Maintainer  : Trevor L. McDonell <trevor.mcdonell@gmail.com>
-- Stability   : experimental
-- Portability : non-portable (GHC extensions)
--

module Data.Array.Accelerate.LLVM.CodeGen.Skeleton (

  Skeleton(..),

) where

import Prelude                                                  hiding ( id )

-- accelerate
import Data.Array.Accelerate.AST                                hiding ( Val(..), prj )
import Data.Array.Accelerate.Array.Representation
import Data.Array.Accelerate.Type

import Data.Array.Accelerate.LLVM.CodeGen.Environment
import Data.Array.Accelerate.LLVM.CodeGen.Monad
import Data.Array.Accelerate.LLVM.CodeGen.Permute
import Data.Array.Accelerate.LLVM.CodeGen.Stencil
import Data.Array.Accelerate.LLVM.CodeGen.Sugar
import Data.Array.Accelerate.LLVM.Compile.Cache


-- | A class covering code generation for all of the primitive array operations.
-- Client backends implement an instance of this class.
--
class Skeleton arch where
  {-# MINIMAL generate, transform
            , fold, fold1 , foldSeg, fold1Seg
            , scanl, scanl', scanl1, scanr, scanr', scanr1
            , permute
            , stencil1, stencil2 #-}

  generate      :: UID
                -> Gamma        aenv
                -> ArrayR            (Array sh e)
                -> IRFun1  arch aenv (sh -> e)
                -> CodeGen arch      (IROpenAcc arch aenv (Array sh e))

  transform     :: UID
                -> Gamma        aenv
                -> ArrayR            (Array sh  a)
                -> ArrayR            (Array sh' b)
                -> IRFun1  arch aenv (sh' -> sh)
                -> IRFun1  arch aenv (a -> b)
                -> CodeGen arch      (IROpenAcc arch aenv (Array sh' b))

  map           :: UID
                -> Gamma        aenv
                -> ArrayR            (Array sh a)
                -> TupleType         b
                -> IRFun1  arch aenv (a -> b)
                -> CodeGen arch      (IROpenAcc arch aenv (Array sh b))

  fold          :: UID
                -> Gamma           aenv
                -> ArrayR               (Array sh e)
                -> IRFun2     arch aenv (e -> e -> e)
                -> IRExp      arch aenv e
                -> MIRDelayed arch aenv (Array (sh, Int) e)
                -> CodeGen    arch      (IROpenAcc arch aenv (Array sh e))

  fold1         :: UID
                -> Gamma           aenv
                -> ArrayR               (Array sh e)
                -> IRFun2     arch aenv (e -> e -> e)
                -> MIRDelayed arch aenv (Array (sh, Int) e)
                -> CodeGen    arch      (IROpenAcc arch aenv (Array sh e))

  foldSeg       :: UID
                -> Gamma           aenv
                -> ArrayR               (Array (sh, Int) e)
                -> IntegralType i
                -> IRFun2     arch aenv (e -> e -> e)
                -> IRExp      arch aenv e
                -> MIRDelayed arch aenv (Array (sh, Int) e)
                -> MIRDelayed arch aenv (Segments i)
                -> CodeGen    arch      (IROpenAcc arch aenv (Array (sh, Int) e))

  fold1Seg      :: UID
                -> Gamma           aenv
                -> ArrayR               (Array (sh, Int) e)
                -> IntegralType i
                -> IRFun2     arch aenv (e -> e -> e)
                -> MIRDelayed arch aenv (Array (sh, Int) e)
                -> MIRDelayed arch aenv (Segments i)
                -> CodeGen    arch      (IROpenAcc arch aenv (Array (sh, Int) e))

  scanl         :: UID
                -> Gamma           aenv
                -> ArrayR               (Array (sh, Int) e)
                -> IRFun2     arch aenv (e -> e -> e)
                -> IRExp      arch aenv e
                -> MIRDelayed arch aenv (Array (sh, Int) e)
                -> CodeGen    arch      (IROpenAcc arch aenv (Array (sh, Int) e))

  scanl'        :: UID
                -> Gamma           aenv
                -> ArrayR               (Array (sh, Int) e)
                -> IRFun2     arch aenv (e -> e -> e)
                -> IRExp      arch aenv e
                -> MIRDelayed arch aenv (Array (sh, Int) e)
                -> CodeGen    arch      (IROpenAcc arch aenv (Array (sh, Int) e, Array sh e))

  scanl1        :: UID
                -> Gamma           aenv
                -> ArrayR               (Array (sh, Int) e)
                -> IRFun2     arch aenv (e -> e -> e)
                -> MIRDelayed arch aenv (Array (sh, Int) e)
                -> CodeGen    arch      (IROpenAcc arch aenv (Array (sh, Int) e))

  scanr         :: UID
                -> Gamma           aenv
                -> ArrayR               (Array (sh, Int) e)
                -> IRFun2     arch aenv (e -> e -> e)
                -> IRExp      arch aenv e
                -> MIRDelayed arch aenv (Array (sh, Int) e)
                -> CodeGen    arch      (IROpenAcc arch aenv (Array (sh, Int) e))

  scanr'        :: UID
                -> Gamma           aenv
                -> ArrayR               (Array (sh, Int) e)
                -> IRFun2     arch aenv (e -> e -> e)
                -> IRExp      arch aenv e
                -> MIRDelayed arch aenv (Array (sh, Int) e)
                -> CodeGen    arch      (IROpenAcc arch aenv (Array (sh, Int) e, Array sh e))

  scanr1        :: UID
                -> Gamma           aenv
                -> ArrayR               (Array (sh, Int) e)
                -> IRFun2     arch aenv (e -> e -> e)
                -> MIRDelayed arch aenv (Array (sh, Int) e)
                -> CodeGen    arch      (IROpenAcc arch aenv (Array (sh, Int) e))

  permute       :: UID
                -> Gamma             aenv
                -> ArrayR                 (Array sh e)
                -> ShapeR                 sh'
                -> IRPermuteFun arch aenv (e -> e -> e)
                -> IRFun1       arch aenv (sh -> sh')
                -> MIRDelayed   arch aenv (Array sh e)
                -> CodeGen      arch      (IROpenAcc arch aenv (Array sh' e))

  backpermute   :: UID
                -> Gamma          aenv
                -> ArrayR              (Array sh e)
                -> ShapeR              sh'
                -> IRFun1    arch aenv (sh' -> sh)
                -> CodeGen   arch      (IROpenAcc arch aenv (Array sh' e))

  stencil1      :: UID
                -> Gamma aenv
                -> StencilR sh a stencil
                -> TupleType b
                -> IRFun1     arch aenv (stencil -> b)
                -> IRBoundary arch aenv (Array sh a)
                -> MIRDelayed arch aenv (Array sh a)
                -> CodeGen    arch      (IROpenAcc arch aenv (Array sh b))

  stencil2      :: UID
                -> Gamma aenv
                -> StencilR sh a stencil1
                -> StencilR sh b stencil2
                -> TupleType c
                -> IRFun2 arch aenv (stencil1 -> stencil2 -> c)
                -> IRBoundary arch aenv (Array sh a)
                -> MIRDelayed arch aenv (Array sh a)
                -> IRBoundary arch aenv (Array sh b)
                -> MIRDelayed arch aenv (Array sh b)
                -> CodeGen    arch      (IROpenAcc arch aenv (Array sh c))

  -- Default instances
  -- -----------------
  map           = defaultMap
  backpermute   = defaultBackpermute


{-# INLINE id #-}
id :: forall arch aenv a. IRFun1 arch aenv (a -> a)
id = IRFun1 return

{-# INLINEABLE defaultMap #-}
defaultMap
    :: Skeleton arch
    => UID
    -> Gamma        aenv
    -> ArrayR (Array sh a)
    -> TupleType b
    -> IRFun1  arch aenv (a -> b)
    -> CodeGen arch      (IROpenAcc arch aenv (Array sh b))
defaultMap uid aenv repr@(ArrayR shr _) tp f
  = transform uid aenv repr (ArrayR shr tp) id f

{-# INLINEABLE defaultBackpermute #-}
defaultBackpermute
    :: Skeleton arch
    => UID
    -> Gamma          aenv
    -> ArrayR (Array sh e)
    -> ShapeR sh'
    -> IRFun1    arch aenv (sh' -> sh)
    -> CodeGen   arch      (IROpenAcc arch aenv (Array sh' e))
defaultBackpermute uid aenv repr@(ArrayR _ tp) shr p
  = transform uid aenv repr (ArrayR shr tp) p id

