// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

#include <xparameters.h>
#include <xparameters_ps.h>
#include <xil_cache.h>
#include <xscugic.h>
#include <lwip/tcp.h>
#include <xil_printf.h>
#include <netif/xadapter.h>
#include <xttcps.h>
#include "numbat.h"

#define INTC_DEVICE_ID          XPAR_SCUGIC_SINGLE_DEVICE_ID
#define TIMER_DEVICE_ID         XPAR_XTTCPS_0_DEVICE_ID
#define TIMER_IRPT_INTR         XPAR_XTTCPS_0_INTR
#define INTC_BASE_ADDR          XPAR_SCUGIC_0_CPU_BASEADDR
#define INTC_DIST_BASE_ADDR     XPAR_SCUGIC_0_DIST_BASEADDR

#define ETH_LINK_DETECT_INTERVAL 4
// 50 ms per https://github.com/Xilinx/embeddedsw/blob/master/lib/sw_apps/lwip_tcp_perf_server/src/platform_zynqmp.c
#define PLATFORM_TIMER_INTR_RATE_HZ (20)

static XTtcPs TimerInstance;
static XInterval Interval;
static u8 Prescaler;

volatile int TcpFastTmrFlag = 0;
volatile int TcpSlowTmrFlag = 0;

extern struct netif *uci_netif;

static void
platform_clear_interrupt(XTtcPs * TimerInstance)
{
        u32 StatusEvent;

        StatusEvent = XTtcPs_GetInterruptStatus(TimerInstance);
        XTtcPs_ClearInterruptStatus(TimerInstance, StatusEvent);
}

static void
timer_callback(XTtcPs * TimerInstance)
{
        static int DetectEthLinkStatus = 0;
        /* we need to call tcp_fasttmr & tcp_slowtmr at intervals specified
         * by lwIP. It is not important that the timing is absoluetly accurate.
         */
        static int odd = 1;
        DetectEthLinkStatus++;
        TcpFastTmrFlag = 1;
        odd = !odd;
        if (odd)
        {
                TcpSlowTmrFlag = 1;
        }

        /* For detecting Ethernet phy link status periodically */
        if (DetectEthLinkStatus == ETH_LINK_DETECT_INTERVAL)
        {
                eth_link_detect(uci_netif);
                DetectEthLinkStatus = 0;
        }

        platform_clear_interrupt(TimerInstance);
}

static void
platform_setup_timer(void)
{
        int Status;
        XTtcPs *Timer = &TimerInstance;
        XTtcPs_Config *Config;

        Config = XTtcPs_LookupConfig(TIMER_DEVICE_ID);

        Status = XTtcPs_CfgInitialize(Timer, Config, Config->BaseAddress);
        if (Status != XST_SUCCESS)
        {
                xil_printf("In %s: Timer Cfg initialization failed...\r\n", __PRETTY_FUNCTION__);
                return;
        }
        XTtcPs_SetOptions(Timer, XTTCPS_OPTION_INTERVAL_MODE | XTTCPS_OPTION_WAVE_DISABLE);
        XTtcPs_CalcIntervalFromFreq(Timer, PLATFORM_TIMER_INTR_RATE_HZ, &Interval, &Prescaler);
        XTtcPs_SetInterval(Timer, Interval);
        XTtcPs_SetPrescaler(Timer, Prescaler);
}

void
platform_setup_interrupts(void)
{
        Xil_ExceptionInit();

        XScuGic_DeviceInitialize(INTC_DEVICE_ID);

        /*
         * Connect the interrupt controller interrupt handler to the hardware
         * interrupt handling logic in the processor.
         */
        Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_IRQ_INT, (Xil_ExceptionHandler) XScuGic_DeviceInterruptHandler, (void *)INTC_DEVICE_ID);
        /*
         * Connect the device driver handler that will be called when an
         * interrupt for the device occurs, the handler defined above performs
         * the specific interrupt processing for the device.
         */
        XScuGic_RegisterHandler(INTC_BASE_ADDR, TIMER_IRPT_INTR, (Xil_ExceptionHandler) timer_callback, (void *)&TimerInstance);
        /*
         * Enable the interrupt for scu timer.
         */
        XScuGic_EnableIntr(INTC_DIST_BASE_ADDR, TIMER_IRPT_INTR);

        return;
}

void
platform_enable_interrupts()
{
        /*
         * Enable non-critical exceptions.
         */
        Xil_ExceptionEnableMask(XIL_EXCEPTION_IRQ);
        XScuGic_EnableIntr(INTC_DIST_BASE_ADDR, TIMER_IRPT_INTR);
        XTtcPs_EnableInterrupts(&TimerInstance, XTTCPS_IXR_INTERVAL_MASK);
        XTtcPs_Start(&TimerInstance);
        return;
}

void
init_platform()
{
        platform_setup_timer();
        platform_setup_interrupts();

        return;
}
