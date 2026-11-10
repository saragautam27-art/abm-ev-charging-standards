setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

library(tidyverse)
library(data.table)


# main 200-run BehaviorSpace output, header rows stripped
f <- fread(file.path("..", "data", "Project_Draft5 Thesisrun2-table.csv"), skip = 6)

setnames(f, c("run_number", "policy_mode", "highway_corridor",
               "nacs_initial_seed", "adaptive_threshold", "retrofit_cost",
               "step", "nacs_market_share", "cumulative_subsidy_wasted",
               "total_trips_failed", "total_consumers_replaced"))

str(f)

# 1 subsidy wasted

subsidy_by_run <- f %>%
  group_by(run_number, policy_mode, highway_corridor) %>%
  summarise(final_waste = max(cumulative_subsidy_wasted), .groups = "drop")

# overall Adaptive vs Static, pooling both topologies
t.test(final_waste ~ policy_mode, data = subsidy_by_run)

subsidy_by_run %>%
  group_by(highway_corridor, policy_mode) %>%
  summarise(avg_waste = mean(final_waste),
            sd_waste = sd(final_waste),
            n = n(),
            .groups = "drop")

# same test ; split by topology, since the effect turned out to be conditional on this
t.test(final_waste ~ policy_mode, data = filter(subsidy_by_run, highway_corridor == "Linear Grid"))
t.test(final_waste ~ policy_mode, data = filter(subsidy_by_run, highway_corridor == "Scale-Free Hubs"))


# 2. final NACS market share (H3) 

final_shares <- f %>%
  group_by(run_number, policy_mode, highway_corridor) %>%
  summarise(final_share = last(nacs_market_share), .groups = "drop")

final_shares %>%
  group_by(highway_corridor, policy_mode) %>%
  summarise(
    min = min(final_share),
    q25 = quantile(final_share, 0.25),
    median = median(final_share),
    q75 = quantile(final_share, 0.75),
    max = max(final_share),
    .groups = "drop"
  )

# medians look reversed from what I expected, variance instead
var.test(final_share ~ highway_corridor, data = filter(final_shares, policy_mode == "Adaptive"))
var.test(final_share ~ highway_corridor, data = filter(final_shares, policy_mode == "Static"))

# medians aren't normal-ish across topologies (long right tail in Scale-Free Hubs), so Wilcoxon instead of a t-test here
wilcox.test(final_share ~ highway_corridor, data = filter(final_shares, policy_mode == "Static"))
wilcox.test(final_share ~ highway_corridor, data = filter(final_shares, policy_mode == "Adaptive"))


# 3. consumer friction (total trips failed) 

friction_by_run <- f %>%
  group_by(run_number, policy_mode, highway_corridor) %>%
  summarise(final_friction = max(total_trips_failed), .groups = "drop")

t.test(final_friction ~ policy_mode, data = friction_by_run)


#Figure 1: subsidy waste by policy and topology

waste_plot_data <- subsidy_by_run %>%
  group_by(highway_corridor, policy_mode) %>%
  summarise(mean_waste = mean(final_waste),
            se = sd(final_waste) / sqrt(n()),
            .groups = "drop")

ggplot(waste_plot_data, aes(x = highway_corridor, y = mean_waste, fill = policy_mode)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.6) +
  geom_errorbar(aes(ymin = mean_waste - se, ymax = mean_waste + se),
                position = position_dodge(width = 0.7), width = 0.2) +
  labs(title = "Cumulative Subsidy Waste by Policy Mode and Topology",
       subtitle = "Error bars show ±1 standard error across 50 runs per scenario",
       x = "Highway Corridor Topology", y = "Mean Cumulative Subsidy Wasted",
       fill = "Policy Mode") +
  scale_fill_manual(values = c("Adaptive" = "#2E86AB", "Static" = "#C73E1D")) +
  theme_minimal()

ggsave("Graph1_SubsidyWaste.png", width = 8, height = 5, dpi = 300)


# Figure 2: NACS share over time, all runs + mean 

summary_curve <- f %>%
  group_by(step, highway_corridor, policy_mode) %>%
  summarise(mean_share = mean(nacs_market_share), .groups = "drop")

ggplot() +
  geom_line(data = f, aes(x = step, y = nacs_market_share, group = run_number),
            color = "grey75", alpha = 0.3, linewidth = 0.3) +
  geom_line(data = summary_curve, aes(x = step, y = mean_share),
            color = "#2E86AB", linewidth = 1.1) +
  facet_grid(policy_mode ~ highway_corridor) +
  labs(title = "NACS Market Share Over Time",
       subtitle = "Grey lines: individual runs. Blue line: mean across 50 runs.",
       x = "Simulation Step (Week)", y = "NACS Market Share (%)") +
  theme_minimal()

ggsave("Graph2_SCurve.png", width = 10, height = 7, dpi = 300)


# Figure 3: spread of final share by topology (this is the one that shows the variance difference) 

ggplot(final_shares, aes(x = highway_corridor, y = final_share, fill = highway_corridor)) +
  geom_boxplot(alpha = 0.7, outlier.shape = 16) +
  geom_jitter(width = 0.15, alpha = 0.3, size = 1) +
  facet_wrap(~ policy_mode) +
  labs(title = "Distribution of Final NACS Market Share by Topology",
       subtitle = "Scale-Free Hubs shows far greater variance and higher ceiling outcomes",
       x = NULL, y = "Final NACS Market Share (%)") +
  scale_fill_manual(values = c("Linear Grid" = "#8E9AAF", "Scale-Free Hubs" = "#F18F01")) +
  theme_minimal() +
  theme(legend.position = "none")

ggsave("Graph3_VarianceSpread.png", width = 9, height = 5.5, dpi = 300)


# Figure 4: consumer friction by policy and topology

friction_plot_data <- friction_by_run %>%
  group_by(highway_corridor, policy_mode) %>%
  summarise(mean_friction = mean(final_friction),
            se = sd(final_friction) / sqrt(n()),
            .groups = "drop")

ggplot(friction_plot_data, aes(x = highway_corridor, y = mean_friction, fill = policy_mode)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.6) +
  geom_errorbar(aes(ymin = mean_friction - se, ymax = mean_friction + se),
                position = position_dodge(width = 0.7), width = 0.2) +
  labs(title = "Total Trips Failed by Policy Mode and Topology",
       subtitle = "Adaptive policy does not significantly reduce consumer friction",
       x = "Highway Corridor Topology", y = "Mean Total Trips Failed",
       fill = "Policy Mode") +
  scale_fill_manual(values = c("Adaptive" = "#2E86AB", "Static" = "#C73E1D")) +
  theme_minimal()

ggsave("Graph4_ConsumerFriction.png", width = 8, height = 5, dpi = 300)


# Figure 5: waste accumulation over time (shows where the two policies start to diverge)

waste_curve <- f %>%
  group_by(step, highway_corridor, policy_mode) %>%
  summarise(mean_waste = mean(cumulative_subsidy_wasted), .groups = "drop")

ggplot(waste_curve, aes(x = step, y = mean_waste, color = policy_mode)) +
  geom_line(linewidth = 1) +
  facet_wrap(~ highway_corridor) +
  labs(title = "Cumulative Subsidy Waste Over Time",
       x = "Simulation Step (Week)", y = "Mean Cumulative Subsidy Wasted",
       color = "Policy Mode") +
  scale_color_manual(values = c("Adaptive" = "#2E86AB", "Static" = "#C73E1D")) +
  theme_minimal()

ggsave("Graph5_WasteTrajectory.png", width = 9, height = 5, dpi = 300)


# Holm-Bonferroni correction across all 8 tests reported in Results 

p_values <- c(
  "Waste_Overall"          = 1.58e-05,
  "Waste_LinearGrid"       = 0.405,
  "Waste_ScaleFreeHubs"    = 7.79e-06,
  "ConsumerFriction"       = 0.214,
  "H3_Wilcoxon_Static"     = 0.00268,
  "H3_Wilcoxon_Adaptive"   = 4.28e-05,
  "H3_Ftest_Static"        = 2.2e-16,
  "H3_Ftest_Adaptive"      = 2.2e-16
)

adjusted <- p.adjust(p_values, method = "holm")

result <- data.frame(
  Test    = names(p_values),
  Raw_p   = p_values,
  Holm_p  = adjusted,
  Sig_05  = adjusted < 0.05
)

print(result)
write.csv(result, "holm_correction_results.csv", row.names = FALSE)


grep("group_by", readLines("R_Plotting.R"), value = TRUE)
