module Main where

import Data.Char( isSpace, isDigit )
import Data.Time.Clock( UTCTime(..), getCurrentTime )
import Data.Time.Calendar( toGregorian )
import Text.Printf

--------------------------------------------------------------------------------

main :: IO ()
main =
  do now <- (toGregorian . utctDay) `fmap` getCurrentTime
  
     -- reading in the talks
     tab <- readConfigFile "talks"
     let ts   = talks tab
         zoom = concat (take 1 [ link | ("zoom",[link]) <- tab ])
     putStrLn ("found " ++ show (length ts) ++ " talks")
     
     -- producing index.html
     s <- readFile "template.html"
     let ls = lines s
     writeFile "index.html" $ unlines $
          take 1 ls
       ++ [ "<!-- DO NOT EDIT THIS FILE, IT'S AUTOMATICALLY GENERATED! -->"
          ]
       ++ takeWhile (not . isTalksPlaceHolder) (drop 1 ls)
       ++ showTalks now ts zoom
       ++ drop 1 (dropWhile (not . isTalksPlaceHolder) ls)
 where
  isTalksPlaceHolder = ("%%%TALKS%%%" ==) . take 11

--------------------------------------------------------------------------------

readConfigFile :: FilePath -> IO [(String,[String])]
readConfigFile file =
  do s <- readFile file
     return (parse (filter (not . isLine) (lines s)))
 where
  isLine s = length s >= 5 && all (=='-') (filter (not . isSpace) s)

  parse (('#':l):ls) = parseItem l ls
  parse (_:ls)       = parse ls
  parse []           = []

  parseItem l ls = parseArgs what [arg0 | not (null arg0)] ls
   where
    what = takeWhile (not . isSpace) l
    arg0 = clean (dropWhile (not . isSpace) l)

  parseArgs what args (l:ls) | take 1 l /= "#" =
    parseArgs what (l:args) ls

  parseArgs what args ls =
    (what, reverse (dropWhile (all isSpace) args)) : parse ls

--------------------------------------------------------------------------------

data Talk = Talk
  { date     :: (Integer,Int,Int)
  , speaker  :: String
  , title    :: String
  , host     :: String
  , abstract :: [String]
  , audience :: String
  , tags     :: [String]
  , bio      :: [String]
  , video    :: String
  , live     :: String
  , slido    :: String
  , slidocode:: String
  , slides   :: String
  }
 deriving ( Show )

talks :: [(String,[String])] -> [Talk]
talks tab 
  | null tab' = []
  | otherwise = talk (take 1 tab' ++ takeWhile ((dt /=) . fst) (drop 1 tab'))
              : talks (drop 1 tab')
 where
  dt   = "date"
  tab' = dropWhile ((dt /=) . fst) tab

  talk tab =
    Talk { date     = parseDate (unwords (tag "date"))
         , speaker  = unwords (tag "speaker")
         , title    = unwords (tag "title")
         , host     = unwords (tag "host")
         , abstract = tag "abstract"
         , audience = unwords (tag "audience")
         , tags     = words (unwords (tag "tags"))
         , bio      = tag "bio"
         , video    = unwords (tag "video")
         , live     = unwords (tag "youtube")
         , slido    = unwords (tag "slido")
         , slidocode= unwords (tag "slidocode")
         , slides   = unwords (tag "slides")
         }
   where
    tag t = [ l | (x,ls) <- tab, x == t, l <- ls ]

  parseDate [y1,y2,y3,y4,'-',m1,m2,'-',d1,d2] | all isDigit [y1,y2,y3,y4,m1,m2,d1,d2] =
    (read [y1,y2,y3,y4], read [m1,m2], read [d1,d2])
  parseDate s = error ("parseDate " ++ show s)

showTalks :: (Integer,Int,Int) -> [Talk] -> String -> [String]
showTalks now ts zoom =
  [ sepa "upcoming talks"
  ] ++
  concat
  [ showTalk t "blue"
  | t <- ts
  , date t >= now
  ] ++
  [ sepa "past talks"
  | any ((< now) . date) ts
  ] ++
  concat
  [ showTalk t "red"
  | t <- ts
  , date t < now
  ]
 where
  showTalk t col =
    [ "<div class='w3-container w3-padding-small w3-border-" ++ col ++ " w3-border'>"
    , strong (showDate (date t)) ++ br
    , larger (show (title t)) ++ br
    , "by " ++ speaker t
    , ralign ("Host: " ++ host t) ++ br
    , hr
    ] ++ abstract t ++
    [ br
    ] ++
    [ x | x <-
      [ startBio
      ] ++
      bio t ++
      [ endBio, br
      ]
    , not (null (bio t))
    ] ++
    [ br ++ strong "audience" ++ ": " ++ audience t
    | not (null (audience t))
    ] ++
    [ hr
    , strong (unwords (tags t))
      ++ ralign (if null (video t) then
                    "Monday " ++ showDate (date t) ++ ", 7am PDT / 10am EDT / 16:00 CEST" ++
                    (useLink (live t) $ \link -> " (" ++ link "YouTube" ++ ")") ++
                    (useLink (slido t) $ \link ->
                      " (" ++ link "Sli.do" ++ ", event code #" ++ slidocode t ++ ")")
                 else
                    link (video t) "Seminar video on Youtube" ++
                    useLink (slides t) (\link -> " (" ++ link "slides" ++ ")"))
    , "</div>"
    , "<p> </p>"
    ]

  br       = "<br>"
  hr       = "<hr>"
  --p        = "<p>" -- we should avoid single "<p>"s
  strong s = "<strong>" ++ s ++ "</strong>"
  larger s = "<span style='font-size:larger'>" ++ s ++ "</span>"
  ralign s = "<span style='float:right'>" ++ s ++ "</span>"
  link l s = "<a href=" ++ show l ++ " target=\"_blank\">" ++ s ++ "</a>"
  sepa s   = "<p class='w3-center'><strong>" ++ s ++ "</strong></p>"
  startBio = "<br><span style='font-size:smaller;font-style:italic'>"
  endBio   = "</span>"

  showMonth 5 = "May"
  showMonth 6 = "June"
  showMonth 7 = "July"

  useLink s f = if null s then "" else f $ link s
  
showDate :: (Integer, Int, Int) -> String
showDate (y,m,d) = printf "%4i-%02i-%02i" y m d
  -- showMonth m ++ " " ++ show d
--------------------------------------------------------------------------------

clean :: String -> String
clean = unwords . words

--------------------------------------------------------------------------------

