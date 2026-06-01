# Data Dictionary sipp1991.dta

Source: 1991 Survey of Income and Program Participation (SIPP).
Sample construction follows Abadie (2003). Accessed via the `DoubleML`
R package (`fetch_401k()`).

N = 9,915 household-level observations.

| Variable  | Type       | Description                                      | Units / Values        |
|-----------|------------|--------------------------------------------------|-----------------------|
| net_tfa   | Continuous | Net total financial assets (outcome)             | USD                   |
| e401      | Binary     | = 1 if employer offers a 401(k) plan (treatment) | 0 / 1                 |
| age       | Continuous | Age of household head                            | Years                 |
| inc       | Continuous | Household income                                 | USD                   |
| educ      | Continuous | Years of education of household head             | Years                 |
| fsize     | Discrete   | Family size                                      | Number of persons     |
| marr      | Binary     | = 1 if married                                   | 0 / 1                 |
| twoearn   | Binary     | = 1 if two-earner household                      | 0 / 1                 |
| db        | Binary     | = 1 if individual has a defined benefit pension  | 0 / 1                 |
| pira      | Binary     | = 1 if individual participates in an IRA plan    | 0 / 1                 |
| hown      | Binary     | = 1 if home owner                                | 0 / 1                 |
| p401      | Binary     | = 1 if individual participates in 401(k) plan    | 0 / 1 (instrument)    |

Variables used in replication: net_tfa, e401, age, inc, educ, fsize,
marr, twoearn, db, pira, hown (9 covariates).
