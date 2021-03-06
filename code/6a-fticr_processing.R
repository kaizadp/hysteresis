# HYSTERESIS AND SOIL CARBON
# Kaizad F. Patel
# March 2020

# 6a-fticr_processing.R

 ## this script will process the input data and metadata files and
 ## generate clean files that can be used for subsequent analysis.
 ## each dataset will generate longform files of (a) all cores, (b) summarized data for each treatment (i.e. cores combined) 

############### #
############### #

source("code/0-hysteresis_packages.R")

# ------------------------------------------------------- ----

## step 1: load the files ----
fticr_report = read.csv("data/fticr/Report-08-28-2020_SCL_newfilters.csv") %>% 
  filter(Mass>200 & Mass<900) %>% 
# a. remove isotopes
  filter(C13==0) %>% 
# b. remove peaks without C assignment
  filter(C>0)

# this has metadata as well as sample data
# split them

# 1a. create meta file ----
fticr_meta = 
  fticr_report %>% 
  dplyr::select(-starts_with("FT")) %>% 
# select only necessary columns
  dplyr::select(Mass, C, H, O, N, S, P, El_comp, Class) %>% 
# we don't want to use this set of boundary conditions for Class assignments
# rename Class to Class_old, create a new blank column Class, and we will fill that in later
  rename(Class_old = Class) %>% 
  mutate(Class = "") %>% 
# c. create columns for indices
  dplyr::mutate(AImod = round((1+C-(0.5*O)-S-(0.5*(N+P+H)))/(C-(0.5*O)-S-N-P),4),
                NOSC =  round(4-(((4*C)+H-(3*N)-(2*O)-(2*S))/C),4),
                HC = round(H/C,2),
                OC = round(O/C,2),
                DBE_AI = 1+C-O-S-0.5*(N+P+H),
                DBE =  1 + ((2*C-H + N + P))/2,
                DBE_C = DBE_AI/C) %>% 
# d. create new Class assignments, based on Seidel et al. 2014 (http://dx.doi.org/10.1016/j.gca.2014.05.038)
  mutate(Class = case_when(AImod>0.66 ~ "condensed aromatic",
                           AImod<=0.66 & AImod > 0.50 ~ "aromatic",
                           AImod <= 0.50 & HC < 1.5 ~ "unsaturated/lignin",
                           HC >= 1.5 ~ "aliphatic"),
         Class = replace_na(Class, "other"),
         Class_detailed = case_when(AImod>0.66 ~ "condensed aromatic",
                                    AImod<=0.66 & AImod > 0.50 ~ "aromatic",
                                    AImod <= 0.50 & HC < 1.5 ~ "unsaturated/lignin",
                                    HC >= 2.0 & OC >= 0.9 ~ "carbohydrate",
                                    HC >= 2.0 & OC < 0.9 ~ "lipid",
                                    HC < 2.0 & HC >= 1.5 & N==0 ~ "aliphatic",
                                    HC < 2.0 & HC >= 1.5 & N > 0 ~ "aliphatic+N")) %>%
  
# e. create column/s for formula
# first, create columns for individual elements
# then, combine
  dplyr::mutate(formula_c = if_else(C>0,paste0("C",C),as.character(NA)),
                formula_h = if_else(H>0,paste0("H",H),as.character(NA)),
                formula_o = if_else(O>0,paste0("O",O),as.character(NA)),
                formula_n = if_else(N>0,paste0("N",N),as.character(NA)),
                formula_s = if_else(S>0,paste0("S",S),as.character(NA)),
                formula_p = if_else(P>0,paste0("P",P),as.character(NA)),
                formula = paste0(formula_c,formula_h, formula_o, formula_n, formula_s, formula_p),
                formula = str_replace_all(formula,"NA",""))

meta_hcoc = 
  fticr_meta %>% 
  dplyr::select(Mass, formula, HC, OC)
  
# 1b. create data file ----
fticr_key = read.csv("data/fticr_key.csv")
corekey = read.csv(COREKEY)

corekey_subset = 
  corekey %>% 
  dplyr::select(Core, texture, treatment, sat_level, Core_assignment) %>% 
  dplyr::mutate(Core = as.factor(Core))

fticr_key_full = 
  fticr_key %>% 
  dplyr::mutate(Core = as.factor(Core)) %>% 
  left_join(corekey_subset, by = "Core")

## step 2: clean the files ----
fticr_data_allpeaks = 
  fticr_report %>% 
  dplyr::select(Mass,starts_with("FT")) %>% 
  #tidyr::gather(sample,intensity,FT007:FT006) %>% 
  melt(id = c("Mass"), value.name = "presence", variable.name = "FTICR_ID") %>% 
  dplyr::mutate(presence = if_else(presence>0,1,0)) %>% 
  filter(presence>0) %>% 
  left_join(dplyr::select(fticr_meta, Mass,formula), by = "Mass")  %>% 
  left_join(dplyr::select(fticr_key, Core:FTICR_ID), by = "FTICR_ID") %>% 
# rearrange columns
  dplyr::select(Core, FTICR_ID, Mass, formula, presence) %>% 
  left_join(corekey_subset, by = "Core") %>% 
  dplyr::select(-Mass,-formula, -presence,Mass,formula,presence)

# now we want only peaks that are in 3+ replicates

# create a longform file for peak assignments in each core
fticr_data = 
  fticr_data_allpeaks %>% 
  group_by(Core_assignment,treatment, texture, sat_level,formula) %>% 
  dplyr::mutate(n = n()) %>% 
  filter(n>=3) %>% 
  dplyr::select(-FTICR_ID)

# create a longform file of peaks by treatments only. remove replication
fticr_data_trt = 
  fticr_data_allpeaks %>% 
  group_by(Core_assignment,treatment, texture, sat_level,formula) %>% 
  dplyr::summarize(n = n(),
                   presence = mean(presence)) %>% 
  filter(n>=3) 

## step 3: OUTPUTS ----
write.csv(fticr_data,FTICR_LONG, row.names = FALSE)
write.csv(fticr_data_trt, "data/processed/fticr_longform_bytrt.csv", row.names = FALSE)
write.csv(fticr_meta,FTICR_META, row.names = FALSE)
write.csv(meta_hcoc,FTICR_META_HCOC, row.names = FALSE)
write.csv(fticr_key_full,"data/processed/fticr_key_full.csv", row.names = FALSE)



