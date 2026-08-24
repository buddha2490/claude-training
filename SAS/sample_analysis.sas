/*****************************************************************************
  Program : sample_analysis.sas
  Purpose : Smoke-test program for the SAS 9.4 connection workflow.
            Creates a small sample data set with continuous and character
            variables, then summarizes them with PROC MEANS and PROC FREQ.

  Notes   : No external inputs, no libnames, no macro variables that depend
            on the calling environment. The log and listing destinations are
            controlled by the submitting command (-log / -print), not here,
            so this program is safe to run from any working directory.
*****************************************************************************/

options nodate nonumber ls=100 ps=60 mprint
        formchar='|----|+|---+=|-/\<>*' formdlim='-';
title;
footnote;

/* --- Build the sample data set ------------------------------------------ */
/* 200 subjects, 3 continuous variables and 3 character variables.          */
/* A fixed seed keeps the output reproducible between runs.                 */

data work.sample;
  call streaminit(20260824);

  length subjid $8 armcd $3 arm $20 sex $1 region $12;
  label
    subjid = "Subject Identifier"
    armcd  = "Treatment Arm Code"
    arm    = "Treatment Arm"
    sex    = "Sex"
    region = "Region"
    age    = "Age (years)"
    weight = "Weight (kg)"
    sbp    = "Systolic Blood Pressure (mmHg)"
  ;

  do i = 1 to 200;

    subjid = put(i, z4.);

    /* --- Character variables ------------------------------------------- */
    if mod(i, 2) = 0 then armcd = "TRT";
      else armcd = "PBO";
    if armcd = "TRT" then arm = "Active Treatment";
      else arm = "Placebo";

    if rand("uniform") < 0.48 then sex = "M";
      else sex = "F";

    select (mod(i, 4));
      when (0) region = "North";
      when (1) region = "South";
      when (2) region = "East";
      otherwise region = "West";
    end;

    /* --- Continuous variables ------------------------------------------ */
    /* Treatment arm gets a small shift in SBP so PROC MEANS BY output is  */
    /* not identical across groups.                                        */
    age    = round(rand("normal", 55, 12), 1);
    weight = round(rand("normal", 78, 14), 0.1);
    sbp    = round(rand("normal", 130, 15) - 4 * (armcd = "TRT"), 1);

    output;
  end;

  drop i;
run;

/* --- Confirm the data set was created ----------------------------------- */
proc contents data=work.sample varnum;
  title1 "Contents of WORK.SAMPLE";
run;

/* --- Frequencies of the character variables ----------------------------- */
proc freq data=work.sample;
  tables armcd arm sex region / nocum;
  tables arm*sex / nopercent norow nocol;
  title1 "PROC FREQ - Character Variables";
run;

/* --- Summary statistics for the continuous variables -------------------- */
proc means data=work.sample n nmiss mean std min q1 median q3 max maxdec=2;
  var age weight sbp;
  title1 "PROC MEANS - Continuous Variables (Overall)";
run;

proc means data=work.sample n mean std min max maxdec=2;
  class arm;
  var age weight sbp;
  title1 "PROC MEANS - Continuous Variables by Treatment Arm";
run;

title;
footnote;
