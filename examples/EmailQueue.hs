{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE DeriveAnyClass    #-}
{-# LANGUAGE RecordWildCards   #-}
import           Control.Exception.Lifted
import           Control.Lens
import           Control.Monad
import           Control.Monad.IO.Class
import           Data.Aeson as Aeson
import           Data.Text
import           Database.Queue
import           Database.Queue.Main
import           GHC.Generics
import           Network.AWS               as AWS
import           Network.AWS.SES.SendEmail as AWS
import           Network.AWS.SES.Types     as AWS

logFailedRequest :: MonadIO m => SendEmailResponse -> m ()
logFailedRequest resp = do
    let stat = view sersResponseStatus resp

    unless (stat >= 200 && stat < 300) $
      liftIO $ putStrLn $ "SES failed with status: " ++ show stat

data Email = Email
  { emailAddress :: Text
  , emailSubject :: Text
  , emailBody    :: Text
  } deriving (Show, Eq, Generic, FromJSON, ToJSON)

makeEmail :: Email -> SendEmail
makeEmail Email {..}
  = sendEmail emailAddress
              (set dToAddresses [emailAddress] destination)
  $ message (content emailSubject)
  $ set bText (Just $ content emailBody) AWS.body

main :: IO ()
main = do
  env <- newEnv Discover
  runResourceT $ runAWS env $ defaultMain "aws-email-queue-consumer" $ \payload _ -> do
    case fromJSON $ pValue payload of
      Aeson.Success email -> do
        resp <- AWS.send $ makeEmail email
        logFailedRequest resp
      Aeson.Error x -> throwIO $ userError $ "Type error. Wrong type of payload. Expected String got " ++
             show x
