### THIS SCRIPT ALLOWS YOU TO SIMULATE THE DATA FLOW OF THE SHINY APP
### IT IS USEFUL FOR TESTING NEW ELEMENTS


# Load functions

# setwd("/home/mhira/shiny_apps/patient-report/") # make sure you are in the app folder, else source files will not be found


source("graphql_functions/getToken.R")
source("graphql_functions/getPatientIds.R")
source("graphql_functions/getPatientReport.R")
source("graphql_functions/getUserProfile.R")
source("utility_functions/simplifyPatRep.R")
source("utility_functions/calculateScales.R")
source("utility_functions/applyCutOffs.R")
source("utility_functions/severityPlot.R")
source("utility_functions/interpretTable.R")
source("utility_functions/extract_cutoffs.R")
source("utility_functions/groupCutoffs.R")
source("graphql_functions/getMultiplePatientReports.R")
source("utility_functions/simplifyMultPatRep.R")
source("utility_functions/split_patient_ids.R")

#Setting

# APP SETTINGS ---------------------------------------------------------------- 

if(!file.exists("settings.R")){
  source("settings-default.R")} else {
    source("settings.R")} # To customise settings, please create settings.R

#patientId = 1 # patient_id can be found from the URL when clicking a report on the patient detail view in MHIRA

# LOAD DATA -------------------------------------------------------------------


token = getToken(Username = "user", Password = "password", url = url)

Patients = getPatientIds(token = token, url = url)
patientIds = Patients$id



# Split patient IDs into smaller batches, e.g., 100 IDs per batch
batch_size <- 100
patient_id_batches <- split_patient_ids(patientIds, batch_size)

# Initialize an empty list to store the results
all_patient_data <- list()

for (batch in patient_id_batches) {
  print(paste("Fetching data for batch of", length(batch), "patients"))
  
  batch_response <- tryCatch({
    getMultiplePatientReports(token = token, patientIds = batch, url = url)
  }, warning = function(w) {
    if (grepl("Session expired! Please login.", w$message)) {
     # showNotification("Session has expired! Please login again.", type = "error", duration = 20)
    #  session$close()
      return(NULL)  # Return NULL to indicate failure
    }
  }, error = function(e) {
  #  showNotification("An error occurred while fetching patient IDs.", type = "error", duration = 20)
  #  session$close()
    return(NULL)  # Return NULL to indicate failure
  })
  
  if (is.null(batch_response$data$generateMultiplePatientReports) || length(batch_response$data$generateMultiplePatientReports) == 0) {next}
  
 
  if (exists("batch_response") && !is.null(batch_response)) {
  response_df <- simplifyMultPatRep(response = batch_response)
  }
  
  
  
  if (exists("response_df") && !is.null(response_df)) {
    all_patient_data <- append(all_patient_data, list(response_df))
  }
}

# Combine all the batch results into a single dataframe
combined_df <- bind_rows(all_patient_data)






simplifiedData = combined_df
data = simplifiedData

questionnaireScripts = simplifiedData$questionnaireScripts %>% list_rbind() %>% unique

cutoffs = extract_cutoffs(questionnaireScripts = questionnaireScripts)

cutoffs = groupCutoffs(cutoffs = cutoffs)

scales = calculateScales(
  simplifiedData = data,
  questionnaireScripts =  questionnaireScripts)

scales = applyCutOffs(scales = scales, cutoffs = cutoffs) 

