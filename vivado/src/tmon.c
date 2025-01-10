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
        int Status;
        XSysMonPsu_Config *ConfigPtr;
        u64 IntrStatus;
        u32 SysMonDeviceId = SYSMON_DEVICE_ID;
        XSysMonPsu *sysmon_inst_ptr = &sysmon_inst;

        /* Initialize the SysMon driver. */
        ConfigPtr = XSysMonPsu_LookupConfig(SysMonDeviceId);
        if (ConfigPtr == NULL)
        {
                return XST_FAILURE;
        }
        XSysMonPsu_CfgInitialize(sysmon_inst_ptr, ConfigPtr, ConfigPtr->BaseAddress);

        /* Self Test the System Monitor device */
        Status = XSysMonPsu_SelfTest(sysmon_inst_ptr);
        if (Status != XST_SUCCESS)
        {
                return XST_FAILURE;
        }

        /*
         * Disable the Channel Sequencer before configuring the Sequence
         * registers.
         */
        XSysMonPsu_SetSequencerMode(sysmon_inst_ptr, XSM_SEQ_MODE_SAFE, XSYSMON_PS);


        /* Disable all the alarms in the Configuration Register 1. */
        XSysMonPsu_SetAlarmEnables(sysmon_inst_ptr, 0x0, XSYSMON_PS);


        /*
         * Setup the Averaging to be done for the channels in the
         * Configuration 0 register as 16 samples:
         */
        XSysMonPsu_SetAvg(sysmon_inst_ptr, XSM_AVG_16_SAMPLES, XSYSMON_PS);


        /*
         * Enable the averaging on the following channels in the Sequencer
         * registers:
         *      - On-chip Temperature, Supply 1/Supply 3  supply sensors
         *      - Calibration Channel
         */
        Status = XSysMonPsu_SetSeqAvgEnables(sysmon_inst_ptr, XSYSMONPSU_SEQ_CH0_TEMP_MASK |
                                             XSYSMONPSU_SEQ_CH0_SUP1_MASK |
                                             XSYSMONPSU_SEQ_CH0_SUP3_MASK | XSYSMONPSU_SEQ_CH0_CALIBRTN_MASK, XSYSMON_PS);
        if (Status != XST_SUCCESS)
        {
                return XST_FAILURE;
        }

        /*
         * Enable the following channels in the Sequencer registers:
         *      - On-chip Temperature, Supply 1/Supply 3 supply sensors
         *      - Calibration Channel
         */
        Status = XSysMonPsu_SetSeqChEnables(sysmon_inst_ptr, XSYSMONPSU_SEQ_CH0_TEMP_MASK |
                                            XSYSMONPSU_SEQ_CH0_SUP1_MASK |
                                            XSYSMONPSU_SEQ_CH0_SUP3_MASK | XSYSMONPSU_SEQ_CH0_CALIBRTN_MASK, XSYSMON_PS);
        if (Status != XST_SUCCESS)
        {
                return XST_FAILURE;
        }

        /* Clear any bits set in the Interrupt Status Register. */
        IntrStatus = XSysMonPsu_IntrGetStatus(sysmon_inst_ptr);
        XSysMonPsu_IntrClear(sysmon_inst_ptr, IntrStatus);

        /* Enable the Channel Sequencer in continuous sequencer cycling mode. */
        XSysMonPsu_SetSequencerMode(sysmon_inst_ptr, XSM_SEQ_MODE_CONTINPASS, XSYSMON_PS);

        XTime_GetTime(&time_now);
        tmon_temperature_check_time = time_now + 5 * UINT64_C(COUNTS_PER_SECOND);

        return XST_SUCCESS;
}

int
tmon_poll(void)
{
        u32 raw_data;
        XSysMonPsu *sysmon_inst_ptr;

        XTime_GetTime(&time_now);
        if (time_now < tmon_temperature_check_time)
                return XST_SUCCESS;

        sysmon_inst_ptr = &sysmon_inst;

        /*
         * Read the on-chip Temperature Data (Current/Maximum/Minimum)
         * from the ADC data registers.
         */
        raw_data = XSysMonPsu_GetAdcData(sysmon_inst_ptr, XSM_CH_TEMP, XSYSMON_PS);
        tmon_temperature = XSysMonPsu_RawToTemperature_OnChip(raw_data);
        raw_data = XSysMonPsu_GetMinMaxMeasurement(sysmon_inst_ptr, XSM_MAX_TEMP, XSYSMON_PS);
        tmon_max_temperature = XSysMonPsu_RawToTemperature_OnChip(raw_data);
        raw_data = XSysMonPsu_GetMinMaxMeasurement(sysmon_inst_ptr, XSM_MIN_TEMP, XSYSMON_PS);
        tmon_min_temperature = XSysMonPsu_RawToTemperature_OnChip(raw_data);

        tmon_temperature_check_time = time_now + 5 * UINT64_C(COUNTS_PER_SECOND);

        return XST_SUCCESS;
}
