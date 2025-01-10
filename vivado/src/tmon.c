// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

#include <stdio.h>
#include <xsysmonpsu.h>
#include <xstatus.h>
#include <xtime_l.h>
#include "xparameters.h"

#define SYSMON_DEVICE_ID XPAR_XSYSMONPSU_0_DEVICE_ID

static XSysMonPsu sysmon_inst;
static XTime time_now;
XTime tmon_temperature_check_time;
float tmon_temperature;
float tmon_max_temperature;
float tmon_min_temperature;

int
tmon_init(void)
{
        int status;
        XSysMonPsu_Config *config_ptr;
        u64 intr_status;
        XSysMonPsu *sysmon_inst_ptr = &sysmon_inst;

        config_ptr = XSysMonPsu_LookupConfig(SYSMON_DEVICE_ID);
        if (config_ptr == NULL)
                return XST_FAILURE;
        XSysMonPsu_CfgInitialize(sysmon_inst_ptr, config_ptr, config_ptr->BaseAddress);
        status = XSysMonPsu_SelfTest(sysmon_inst_ptr);
        if (status != XST_SUCCESS)
                return XST_FAILURE;
        XSysMonPsu_SetSequencerMode(sysmon_inst_ptr, XSM_SEQ_MODE_SAFE, XSYSMON_PS);
        XSysMonPsu_SetAlarmEnables(sysmon_inst_ptr, 0x0, XSYSMON_PS);
        XSysMonPsu_SetAvg(sysmon_inst_ptr, XSM_AVG_16_SAMPLES, XSYSMON_PS);
        status = XSysMonPsu_SetSeqAvgEnables(sysmon_inst_ptr, XSYSMONPSU_SEQ_CH0_TEMP_MASK | XSYSMONPSU_SEQ_CH0_CALIBRTN_MASK, XSYSMON_PS);
        if (status != XST_SUCCESS)
                return XST_FAILURE;
        status = XSysMonPsu_SetSeqChEnables(sysmon_inst_ptr, XSYSMONPSU_SEQ_CH0_TEMP_MASK | XSYSMONPSU_SEQ_CH0_CALIBRTN_MASK, XSYSMON_PS);
        if (status != XST_SUCCESS)
                return XST_FAILURE;
        intr_status = XSysMonPsu_IntrGetStatus(sysmon_inst_ptr);
        XSysMonPsu_IntrClear(sysmon_inst_ptr, intr_status);
        XSysMonPsu_SetSequencerMode(sysmon_inst_ptr, XSM_SEQ_MODE_CONTINPASS, XSYSMON_PS);

        XTime_GetTime(&time_now);
        tmon_temperature_check_time = time_now + 5 * UINT64_C(COUNTS_PER_SECOND);

        return XST_SUCCESS;
}

int
tmon_poll(void)
{
        u32 adc_data;
        XSysMonPsu *sysmon_inst_ptr;

        XTime_GetTime(&time_now);
        if (time_now < tmon_temperature_check_time)
                return XST_SUCCESS;

        sysmon_inst_ptr = &sysmon_inst;

        adc_data = XSysMonPsu_GetAdcData(sysmon_inst_ptr, XSM_CH_TEMP, XSYSMON_PS);
        tmon_temperature = XSysMonPsu_RawToTemperature_OnChip(adc_data);
        adc_data = XSysMonPsu_GetMinMaxMeasurement(sysmon_inst_ptr, XSM_MAX_TEMP, XSYSMON_PS);
        tmon_max_temperature = XSysMonPsu_RawToTemperature_OnChip(adc_data);
        adc_data = XSysMonPsu_GetMinMaxMeasurement(sysmon_inst_ptr, XSM_MIN_TEMP, XSYSMON_PS);
        tmon_min_temperature = XSysMonPsu_RawToTemperature_OnChip(adc_data);

        tmon_temperature_check_time = time_now + 5 * UINT64_C(COUNTS_PER_SECOND);

        return XST_SUCCESS;
}
