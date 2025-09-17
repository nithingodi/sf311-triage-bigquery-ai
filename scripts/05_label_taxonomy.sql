-- Finalize the taxonomy labels by creating a table with a static list.
CREATE OR REPLACE TABLE `@@PROJECT_ID@@.@@DATASET_ID@@.label_taxonomy` AS
SELECT * FROM UNNEST([
  'Illegal Parking','Abandoned Vehicle','Garbage Overflow','Illegal Dumping','Garbage Collection',
  'Debris Removal','Mold/Mildew','Building Maintenance','Tree Maintenance','Vandalism',
  'Noise Complaint','Flooding','Utility Complaint','Employee Conduct',
  'Bulky Items','Encampment','Human/Animal Waste','Street/Sidewalk Defect',
  'Streetlight Out','Hazardous/Medical Waste','Illegal Postings'
]) AS label_value;
