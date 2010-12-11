{-# LANGUAGE OverloadedStrings #-}
-- |Generate a Storable instance for ROS msg types.
module Ros.Core.Msg.StorableInstance (genStorableInstance) where
import Control.Monad ((>=>))
import Data.ByteString.Char8 (ByteString, pack)
import qualified Data.ByteString.Char8 as B
import Data.Maybe (fromJust)
import Ros.Core.Msg.Types
import Ros.Core.Msg.Analysis

genStorableInstance :: Msg -> MsgInfo (ByteString, ByteString)
genStorableInstance msg 
  | null (fields msg) = return ("import Foreign.Storable (Storable(..))\n",
                                singletonStorable)
  | otherwise = isFlat msg >>= aux
    where aux False = return ("", "")
          aux True = do sz <- totalSize msg
                        return (smImp, stInst sz)
          peekFields = map (const "SM.peek") (fields msg)
          pokeFields = map ((\n -> B.concat ["SM.poke (", n, " obj')"]) . 
                            fieldName)
                           (fields msg)
          name = pack (shortName msg)
          stInst sz = B.concat ["instance Storable ", name, " where\n",
                                "  sizeOf _ = ", sz,"\n",
                                "  alignment _ = 8\n",
                                "  peek = SM.runStorable (", name, " <$> ",
                                B.intercalate " <*> " peekFields, ")\n",
                                "  poke ptr' obj' = ",
                                "SM.runStorable store' ptr'\n",
                                "    where store' = ",
                                B.intercalate " *> " pokeFields,"\n\n"]
          smImp = B.concat [ "import Foreign.Storable (Storable(..))\n"
                           , "import qualified Ros.Core.Util.StorableMonad"
                           , " as SM\n" ]
          singletonStorable = B.concat [ "instance Storable ", name, " where\n"
                                       , "  sizeOf _ = 1\n"
                                       , "  alignment _ = 1\n"
                                       , "  peek _ = pure ", name, "\n"
                                       , "  poke _ _ = pure ()\n\n" ]


totalSize :: Msg -> MsgInfo ByteString
totalSize msg = B.intercalate sep `fmap` mapM (aux . fieldType) (fields msg)
    where aux = getTypeInfo >=> return . fromJust . size
          sep = B.append " +\n" $ B.replicate 13 ' '

