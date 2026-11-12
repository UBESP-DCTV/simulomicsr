### C01
ORIGINAL: For each level write a short name (`level`), the text as written in the metadata (`text_as_written`), the name of the entity (`entity`: the agent for a perturbation, the disease or genotype for a state), and the dose and the duration if they are written.
REWRITTEN: Write for each level a short name (`level`), the text as written in the metadata (`text_as_written`), the name of the entity (`entity`: the agent for a perturbation, the disease or genotype for a state), and, if they are written, the dose and the duration.

### C02
ORIGINAL: The stage or the subtype of a disease does not exist for the healthy donors.
REWRITTEN: For the healthy donors, the stage or the subtype of a disease does not exist.

### C03
ORIGINAL: Time is a factor when the series has more than one time point.
REWRITTEN: When the series has a time point, time is a factor.

### C04
ORIGINAL: CONSTANT COLUMNS: the metadata fields that have the same value in every sample;
REWRITTEN: CONSTANT COLUMNS: the metadata fields whose value is the same in every sample;

### C05
ORIGINAL: A factor is a variable of the design: it divides the samples into the groups that the series compares.
REWRITTEN: A factor is a variable of the design: the samples are divided by it into the groups that the series compares.

### C06
ORIGINAL: Write such a nested factor as a separate factor and give the special level `not applicable` to the values of the samples outside it.
REWRITTEN: Write such a nested factor as a separate factor and, to the values of the samples outside it, give the special level `not applicable`.

### C07
ORIGINAL: In `not_understood`, list the samples or the values that you cannot assign, and the factors that no column states for all the samples, each with the reason.
REWRITTEN: List in `not_understood` the samples or the values that you cannot assign, and the factors that no column states for all the samples, each with the reason.

### C08
ORIGINAL: Use an empty array if there are none, and for every other role.
REWRITTEN: If there are none, and for every other role, use an empty array.

### C09
ORIGINAL: If no column states the factor for all the samples, do not write the factor: describe it in `not_understood`.
REWRITTEN: If no column states the factor for some of the samples, do not write the factor: describe it in `not_understood`.

### C10
ORIGINAL: The replicate number and the sample identifier are never a factor.
REWRITTEN: The replicate number and the sample identifier are usually not a factor.

### C11
ORIGINAL: If the factor has no baseline in this series, use the empty string in both fields.
REWRITTEN: Use the empty string in both fields if the factor has no baseline in this series.
