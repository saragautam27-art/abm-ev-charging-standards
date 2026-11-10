setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

# Sensitivity Analysis

library(data.table)
library(dplyr)

# 1: Adaptive-Threshold Sensitivity

threshold_raw <- fread(file.path("..", "data", "Sensitivity_Threshold.csv"),
                       skip = 6, header = TRUE, quote = "")

names(threshold_raw) <- names(threshold_raw) %>%
  gsub('\\[|\\]', '', .) %>%
  gsub('"', '', .) %>%
  gsub('[^A-Za-z0-9]+', '.', .) %>%
  gsub('^\\.|\\.$', '', .)

threshold_raw[] <- lapply(threshold_raw, function(col) {
  if (is.character(col)) gsub('"', '', col) else col
})

threshold_raw <- threshold_raw %>%
  mutate(across(c(run.number, adaptive.threshold, step, nacs.market.share,
                  cumulative.subsidy.wasted, total.trips.failed, total.consumers.replaced),
                as.numeric))


print(unique(threshold_raw$adaptive.threshold))

threshold_final <- threshold_raw %>%
  group_by(run.number) %>%
  filter(step == max(step)) %>%
  ungroup()

threshold_summary <- threshold_final %>%
  group_by(adaptive.threshold) %>%
  summarise(
    mean_waste = mean(cumulative.subsidy.wasted),
    se_waste = sd(cumulative.subsidy.wasted) / sqrt(n()),
    mean_nacs_share = mean(nacs.market.share),
    n = n(),
    .groups = "drop"
  )

print(threshold_summary)
write.csv(threshold_summary, "threshold_summary.csv", row.names = FALSE)



# 2: CCS1 Reliability-Weight Sensitivity


reliability_raw <- fread(file.path("..", "data", "Sensitivity_Reliability.csv"),
                         skip = 6, header = TRUE, quote = "")

names(reliability_raw) <- names(reliability_raw) %>%
  gsub('\\[|\\]', '', .) %>%
  gsub('"', '', .) %>%
  gsub('[^A-Za-z0-9]+', '.', .) %>%
  gsub('^\\.|\\.$', '', .)

reliability_raw[] <- lapply(reliability_raw, function(col) {
  if (is.character(col)) gsub('"', '', col) else col
})

reliability_raw <- reliability_raw %>%
  mutate(across(c(run.number, adaptive.threshold, ccs1.reliability.weight, step,
                  nacs.market.share, cumulative.subsidy.wasted,
                  total.trips.failed, total.consumers.replaced),
                as.numeric))

print(unique(reliability_raw$ccs1.reliability.weight))

reliability_final <- reliability_raw %>%
  group_by(run.number, policy.mode, ccs1.reliability.weight) %>%
  filter(step == max(step)) %>%
  ungroup()

reliability_summary <- reliability_final %>%
  group_by(ccs1.reliability.weight, policy.mode) %>%
  summarise(
    mean_waste = mean(cumulative.subsidy.wasted),
    se_waste = sd(cumulative.subsidy.wasted) / sqrt(n()),
    mean_nacs_share = mean(nacs.market.share),
    n = n(),
    .groups = "drop"
  )

print(reliability_summary)
write.csv(reliability_summary, "reliability_summary.csv", row.names = FALSE)


# Final outputs (4.3)

cat("\n--- Table 5: Threshold Sensitivity ---\n")
print(threshold_summary)

cat("\n--- Table 6: Reliability-Weight Sensitivity ---\n")
print(reliability_summary)