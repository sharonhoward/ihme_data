
# libraries ####
#library(quanteda)
#library(spacyr)
#devtools::install_github("quanteda/quanteda.corpora")
#library(quanteda.corpora)
#devtools::install_github("kbenoit/LIWCalike") # hmmm
#library(LIWCalike)

# nb this can cause a conflict with dplyr::summarise
library(vcd)
library(vcdExtra)

library(igraph)
library(ggraph)

library(patchwork)

library(topicmodels)
library(tidytext)

library(knitr)
library(kableExtra)

library(lubridate)
library(scales)
library(readtext)
library(widyr)
library(tidyverse)




# inquest texts data ####
inquest_texts_data <- readtext("../data/wacwic_txt/*.txt",
                               docvarsfrom = "filenames",
                               dvsep = "txt",
                               docvarnames = c("img_inq_first")
)


# inquest texts -> tibble format 
inquest_texts_data <- as_tibble(inquest_texts_data)  


# summary data ####

cw_summary_data <- read_tsv("../data/wa_coroners_inquests_v1-1.tsv", na="NULL", col_types = cols(doc_date = col_character()))


# prep summary data ####

## add new columns
# inquest_add_type: child, prisoner, multi, none 
# name type named/unnamed 
# clean up doc dates (a couple end -00 [MySQL accepts this as a valid date format but R doesn't] -> -01), then add doc year, doc month
# simplify verdict - merge suicides
## note on joining summary to texts data
# first_img and inquisition_img are both prefixed WACWIC -> eg WACWIC652000003_WACWIC652000002 
# but texts ID (from filename) = WACWIC652000003_652000002 (don't remember why I thought this was a good idea)
# so a little adjustment needed

## filter out 
# unknown/mixed gender and type multi
# unknown verdict (not the same as 'undetermined')
# a random inquest date before 1760 (2891) which I CBA to look up




cw_summary <- cw_summary_data %>% 
  rename(verdict_original = verdict) %>%
  mutate(gender = case_when(
    gender == "f" ~ "female",
    gender == "m" ~ "male",
    TRUE ~ gender),
    inquest_add_type = case_when(
      str_detect(deceased_additional_info, "child") ~ "child",
      str_detect(deceased_additional_info, "p[ri]+soner") ~ "prisoner", # found a typo lol
      str_detect(deceased_additional_info, "multiple") ~ "multiple",
      TRUE ~ "none"),
    
    name_type = ifelse(!str_detect(the_deceased, regex("unnamed", ignore_case=TRUE)), "named", "unnamed") ,
    age_type = ifelse(inquest_add_type =="child", "child", "adult"),
    doc_date = as_date(str_replace(doc_date, "00$", "01")),
    doc_year = year(doc_date),
    doc_month = month(doc_date, label = TRUE),
    verdict = ifelse(str_detect(verdict_original, "suicide"), "suicide", verdict_original)
  ) %>%
  mutate(first_img_no = str_replace(first_img, "WACWIC","")) %>%
  unite(img_inq_first, inquisition_img, first_img_no, remove=FALSE) %>%
  filter(doc_year > 1759, 
         str_detect(gender, "male"), 
         !str_detect(deceased_additional_info, "multi"), 
         verdict !="-") 




# stopwords ####

# early modern stopwords list
# source: http://walshbr.com/textanalysiscoursebook/book/cyborg-readers/voyant-part-one/

#early_modern_stopwords_data <- read_csv("../data/early-modern-stopwords.txt")

# subset of early_modern_stopwords: numbers, short words 5 characters or less
early_modern_stopwords_short_data <- read_csv("../data/early-modern-stopwords-short.txt")


## add corpus specific stopwords

# given names tagged in LL - surnames are less of an issue as they're more varied; also more possibility of coinciding with content words, so reluctant to remove unless it's really necessary

cw_given_data <- 
  read_csv("../data/ll_cw_first_names_20180610.csv")


cw_given <-
  cw_given_data %>% 
  mutate(word = str_to_lower(word)) %>%
  count(word) %>% select(-n) %>% ungroup()


# custom stop words list: specific to corpus/ legal/ numbers written as words/ more general (probably overlap with em stopwords)

custom_stopwords <- c("inquisition", "indented", "westminster", "middlesex", "county", "city", "parish", "liberty", "britain", "france", "ireland", "saint", "st", "day", "year",  "aforesaid", "said", "hereunder","written", "whereof", "coroner", "foreman","jurors",  "names", "men", "prickard", "gell", "esq", "gentleman", "king", "lord", "oath", "duly", "wit", "seals", "presence", "death", "dead", "lying", "body",  "h", "er", "is", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty", "first", "second", "third", "fourth", "fifth", "sixth" , "our", "there", "then", "their", "on", "upon", "for", "that", "at", "being",  "as", "so", "means", "his", "within", "say", "do", "did", "came", "this", "which", "what", "before", "how", "not",  "sworn",  "who", "have", "is", "above", "here")

custom_stopwords <- data_frame(
  word  = custom_stopwords
) 


# numerical strings in the texts to add to the numbers in em stopwords
cw_stop_numbers <- 
  inquest_texts_data %>% select(text) %>% unnest_tokens(word, text) %>%
  filter(str_detect(word, "[0-9]")) %>%
  count(word) %>% select(-n) %>% ungroup()


# combine them all into one
cw_stopwords <- bind_rows(early_modern_stopwords_short_data, custom_stopwords, cw_stop_numbers, cw_given)



# join texts to summary data ####
# inner join excludes a handful which don't have text (not survived/no image/not rekeyed)

cw_inquest_texts <- cw_summary %>% 
  select(img_inq_first, doc_date, doc_year, doc_month, gender, verdict, inquest_add_type, name_type, age_type, inquisition_img) %>%
  inner_join(inquest_texts_data, by="img_inq_first") 


## top-and-tail: remove unwanted formulaic text sections at beginning and end

# these are not exactly the same in each document - a) they contain inserted text, mainly names/dates; b) slight variations in wording and/or rekeying
# but as it turns out, apart from the names, there isn't *much* variation
# possibly unnecessary over-complication, but only use second set of regexes on texts for which the first set have failed 
  
# the end segment can be located by "in witness whereof" in nearly all cases;
# reg_end1 deals with all bar 10; 1 of the remaining seems to be truncated anyway; reg_end2 gets the rest
# don't seem to be any problems with the output, though it's hard to test...

reg_end1 <- "(\\bin +)?(win?th?ne?ss(es)?[[:punct:]]?) +([stw]?here[[:punct:]]? *of|w[eh]+re? *of|whereby|when *of|where *as|when, as well|where was well)"
#to mop up the remainder
reg_end2 <- "(in witness( of as well| of the said| foreman of))|((and|the) said coroner as)|((whereof )?as well( as)? the said coroner)|(musson foreman of the said jurors)|(and not coroner as the said)"

# to remove the start...
# "... upon their oath(s) say" cover nearly everything, just need to account for a few typos
# tested the results and doens't seem to strip anything it shouldn't

start_reg1 <- "(up *on,? *their *[co]aths?( +say)?|(open|do) *their *oath *say|upon *then? *oath say)"
# this works for mopping up
start_reg2 <- "by what means the said"

# process
#  str_split , limit to 2
#  map_chr to extract 2nd element of split; .null  catches fails 

cw_inquest_texts_stripped <-
  cw_inquest_texts %>% select(img_inq_first, text) %>%
  mutate(
    text_split_reg_e1 = map_chr( str_split(text, regex(reg_end1, ignore_case = TRUE), n=2) , 1, .null=NA_character_),
    text_split_reg_e1_test = map_chr( str_split(text, regex(reg_end1, ignore_case = TRUE), n=2) , 2, .null=NA_character_),
    text_split_reg_e2_test = map_chr( str_split(text, regex(reg_end2, ignore_case = TRUE), n=2 ), 2, .null=NA_character_)
  ) %>%
  mutate(text_stripped_end = case_when(
    !is.na(text_split_reg_e1_test) ~ text_split_reg_e1, 
    !is.na(text_split_reg_e2_test) ~ map_chr( str_split(text, regex(reg_end2, ignore_case = TRUE), n=2 ) , 1, .null=NA_character_),
    TRUE ~ text )
  ) %>%
  select(-text_split_reg_e1:-text_split_reg_e2_test) %>%
  mutate(
    text_split_reg1 = map_chr(str_split(text_stripped_end, regex(start_reg1, ignore_case = TRUE), n=2) , 2, .null = NA_character_),
    text_split_reg2 = map_chr(str_split(text_stripped_end, regex(start_reg2, ignore_case=TRUE), n=2) , 2, .null = NA_character_),
    text_stripped = if_else(!is.na(text_split_reg1), text_split_reg1, text_split_reg2) 
  ) %>%
  select(-text_split_reg1, -text_split_reg2, -text, -text_stripped_end)  %>% 
  left_join(cw_summary, by="img_inq_first")

