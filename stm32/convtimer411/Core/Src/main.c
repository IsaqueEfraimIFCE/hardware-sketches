/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.c
  * @brief          : Main program body
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2025 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/
#include "main.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
#include <string.h>
#include <math.h>
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */
/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */

/**
 * @brief Dimensão total do bloco recebido (com borda), 10×10 pixels.
 */
#define IMG_WIDTH_TOTAL   10
#define IMG_HEIGHT_TOTAL  10

/**
 * @brief Dimensão útil da imagem onde a convolução é aplicada (8×8 pixels).
 */
#define IMG_WIDTH_USEFUL  8
#define IMG_HEIGHT_USEFUL 8

/**
 * @brief Quantidade de bytes recebidos por bloco (imagem completa 10×10).
 */
#define BLOCK_RX_SIZE (IMG_WIDTH_TOTAL * IMG_HEIGHT_TOTAL)

/**
 * @brief Quantidade de bytes enviados após processamento (imagem 8×8).
 */
#define BLOCK_TX_SIZE (IMG_WIDTH_USEFUL * IMG_HEIGHT_USEFUL)

/* USER CODE END PD */

/* Private macro -------------------------------------------------------------*/
/* USER CODE BEGIN PM */
/* USER CODE END PM */

/* Private variables ---------------------------------------------------------*/
TIM_HandleTypeDef htim2;
UART_HandleTypeDef huart2;

/* USER CODE BEGIN PV */

/**
 * @brief Buffer de recepção contendo imagem 10×10 enviada pelo host.
 */
uint8_t rx_buffer[BLOCK_RX_SIZE];

/**
 * @brief Buffer de transmissão contendo imagem filtrada 8×8.
 */
uint8_t tx_buffer[BLOCK_TX_SIZE];

/**
 * @brief Sequência de reconhecimento (ACK). Enviada antes e depois de cada bloco.
 */
uint8_t ack[2] = { 0xAA, 0x55 };

uint32_t t_start, t_end, t_exec_us;

/**
 * @brief Kernel 3×3 utilizado no processamento.
 */
// Índices: 0  1  2  3  4
// Pesos:  -2 -1  0 +1 +2
static const int8_t weight_map[5] = { -2, -1, 0, 1, 2 };

/**
 * @brief LUT para multiplicação pixel × peso do kernel Sobel.
 * Dimensão: [256][5]
 */
static int16_t mul_lut[256][5];

#define NUM_BLOCKS 144

const uint8_t FilterIdx[3][3] = {
    { 1, 2, 3 },  // -1, 0, +1
    { 0, 2, 4 },  // -2, 0, +2
    { 1, 2, 3 }
};

/**
 * @brief Inicializa a LUT de multiplicação pixel × peso.
 */
void init_mul_lut(void)
{
    for (int pixel = 0; pixel < 256; pixel++) {
        for (int w = 0; w < 5; w++) {
            mul_lut[pixel][w] = pixel * weight_map[w];
        }
    }
}

/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_USART2_UART_Init(void);
static void MX_TIM2_Init(void);
/* USER CODE BEGIN PFP */

/**
 * @brief Aplica convolução 3×3 somente na área útil (8×8) da imagem.
 *
 * @param input   Imagem de entrada 10×10 (com bordas).
 * @param output  Imagem de saída 8×8 (somente região central).
 * @param filter  Kernel 3×3 a ser aplicado.
 *
 * @details
 * A função ignora os pixels da borda, deslocando o índice adequadamente para
 * mapear a região útil. Valores de saída são saturados para o intervalo [0, 255].
 */
/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */
/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */
int main(void)
{
    init_mul_lut();

    /* USER CODE BEGIN 1 */
    /* USER CODE END 1 */

    /* MCU Configuration------------------------------------------------------*/

    /* Reset of all peripherals, Initializes the Flash interface and the Systick. */
    HAL_Init();

    /* USER CODE BEGIN Init */
    /* USER CODE END Init */

    /* Configure the system clock */
    SystemClock_Config();

    /* USER CODE BEGIN SysInit */
    /* USER CODE END SysInit */

    /* Initialize all configured peripherals */
    MX_GPIO_Init();
    MX_USART2_UART_Init();
    MX_TIM2_Init();

    HAL_TIM_Base_Start(&htim2);

    /* USER CODE BEGIN 2 */
    /* USER CODE END 2 */

    /* Infinite loop */
    /* USER CODE BEGIN WHILE */
    while (1) {
        /* USER CODE END WHILE */

        /* USER CODE BEGIN 3 */
        char msg[64];

        uint32_t t_start, t_end, t_exec_us;

        uint8_t img_in[IMG_HEIGHT_TOTAL][IMG_WIDTH_TOTAL];
        uint8_t img_out[IMG_HEIGHT_USEFUL][IMG_WIDTH_USEFUL];

        /* Inicializa imagem apenas uma vez */
        for (int i = 0; i < IMG_HEIGHT_TOTAL; i++) {
            for (int j = 0; j < IMG_WIDTH_TOTAL; j++) {
                img_in[i][j] = i + j;
            }
        }

        /* Zera o timer para evitar overflow acumulado */
        __HAL_TIM_SET_COUNTER(&htim2, 0);

        /* Início da medição */
        t_start = __HAL_TIM_GET_COUNTER(&htim2);

        /* Executa a convolução 1000 vezes */
        for (int k = 0; k < 1000; k++) {
            apply_convolution_lut(img_in, img_out, FilterIdx);
        }

        /* Fim da medição */
        t_end = __HAL_TIM_GET_COUNTER(&htim2);

        /* Tempo total (assumindo TIM2 configurado em 1 MHz → 1 tick = 1 µs) */
        t_exec_us = t_end - t_start;

        unsigned long medio_us_x1000 = (t_exec_us * 1000UL) / 1000UL;

        int len = snprintf(
            msg,
            sizeof(msg),
            "Total: %lu us | Medio: %lu.%03lu us\r\n",
            (unsigned long)t_exec_us,
            medio_us_x1000 / 1000,
            medio_us_x1000 % 1000
        );

        HAL_UART_Transmit(&huart2, (uint8_t *)msg, len, HAL_MAX_DELAY);
        /* USER CODE END 3 */
    }
}

/**
  * @brief System Clock Configuration
  * @retval None
  */
void SystemClock_Config(void)
{
    RCC_OscInitTypeDef RCC_OscInitStruct = { 0 };
    RCC_ClkInitTypeDef RCC_ClkInitStruct = { 0 };

    /** Configure the main internal regulator output voltage */
    __HAL_RCC_PWR_CLK_ENABLE();
    __HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE1);

    /** Initializes the RCC Oscillators according to the specified parameters */
    RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSI;
    RCC_OscInitStruct.HSIState = RCC_HSI_ON;
    RCC_OscInitStruct.HSICalibrationValue = RCC_HSICALIBRATION_DEFAULT;
    RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
    RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSI;
    RCC_OscInitStruct.PLL.PLLM = 16;
    RCC_OscInitStruct.PLL.PLLN = 336;
    RCC_OscInitStruct.PLL.PLLP = RCC_PLLP_DIV4;
    RCC_OscInitStruct.PLL.PLLQ = 4;

    if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK) {
        Error_Handler();
    }

    /** Initializes the CPU, AHB and APB buses clocks */
    RCC_ClkInitStruct.ClockType =
        RCC_CLOCKTYPE_HCLK |
        RCC_CLOCKTYPE_SYSCLK |
        RCC_CLOCKTYPE_PCLK1 |
        RCC_CLOCKTYPE_PCLK2;

    RCC_ClkInitStruct.SYSCLKSource   = RCC_SYSCLKSOURCE_PLLCLK;
    RCC_ClkInitStruct.AHBCLKDivider  = RCC_SYSCLK_DIV1;
    RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV2;
    RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV1;

    if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_2) != HAL_OK) {
        Error_Handler();
    }
}

/**
  * @brief TIM2 Initialization Function
  * @param None
  * @retval None
  */
static void MX_TIM2_Init(void)
{
    TIM_ClockConfigTypeDef sClockSourceConfig = { 0 };
    TIM_MasterConfigTypeDef sMasterConfig = { 0 };

    htim2.Instance = TIM2;
    htim2.Init.Prescaler         = 31999;
    htim2.Init.CounterMode       = TIM_COUNTERMODE_UP;
    htim2.Init.Period            = 999;
    htim2.Init.ClockDivision     = TIM_CLOCKDIVISION_DIV1;
    htim2.Init.AutoReloadPreload = TIM_AUTORELOAD_PRELOAD_DISABLE;

    if (HAL_TIM_Base_Init(&htim2) != HAL_OK) {
        Error_Handler();
    }

    sClockSourceConfig.ClockSource = TIM_CLOCKSOURCE_INTERNAL;

    if (HAL_TIM_ConfigClockSource(&htim2, &sClockSourceConfig) != HAL_OK) {
        Error_Handler();
    }

    sMasterConfig.MasterOutputTrigger = TIM_TRGO_RESET;
    sMasterConfig.MasterSlaveMode     = TIM_MASTERSLAVEMODE_DISABLE;

    if (HAL_TIMEx_MasterConfigSynchronization(&htim2, &sMasterConfig) != HAL_OK) {
        Error_Handler();
    }
}

/**
  * @brief USART2 Initialization Function
  * @param None
  * @retval None
  */
static void MX_USART2_UART_Init(void)
{
    huart2.Instance        = USART2;
    huart2.Init.BaudRate   = 115200;
    huart2.Init.WordLength = UART_WORDLENGTH_8B;
    huart2.Init.StopBits   = UART_STOPBITS_1;
    huart2.Init.Parity     = UART_PARITY_NONE;
    huart2.Init.Mode       = UART_MODE_TX_RX;
    huart2.Init.HwFlowCtl  = UART_HWCONTROL_NONE;
    huart2.Init.OverSampling = UART_OVERSAMPLING_16;

    if (HAL_UART_Init(&huart2) != HAL_OK) {
        Error_Handler();
    }
}

/**
  * @brief GPIO Initialization Function
  * @param None
  * @retval None
  */
static void MX_GPIO_Init(void)
{
    GPIO_InitTypeDef GPIO_InitStruct = { 0 };

    /* GPIO Ports Clock Enable */
    __HAL_RCC_GPIOC_CLK_ENABLE();
    __HAL_RCC_GPIOH_CLK_ENABLE();
    __HAL_RCC_GPIOA_CLK_ENABLE();
    __HAL_RCC_GPIOB_CLK_ENABLE();

    /* Configure GPIO pin Output Level */
    HAL_GPIO_WritePin(LD2_GPIO_Port, LD2_Pin, GPIO_PIN_RESET);

    /* Configure GPIO pin : B1_Pin */
    GPIO_InitStruct.Pin  = B1_Pin;
    GPIO_InitStruct.Mode = GPIO_MODE_IT_FALLING;
    GPIO_InitStruct.Pull = GPIO_NOPULL;
    HAL_GPIO_Init(B1_GPIO_Port, &GPIO_InitStruct);

    /* Configure GPIO pin : LD2_Pin */
    GPIO_InitStruct.Pin   = LD2_Pin;
    GPIO_InitStruct.Mode  = GPIO_MODE_OUTPUT_PP;
    GPIO_InitStruct.Pull  = GPIO_NOPULL;
    GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
    HAL_GPIO_Init(LD2_GPIO_Port, &GPIO_InitStruct);
}

/* USER CODE BEGIN 4 */
/* ========================================================================== */
/* ========================== Função de convolução =========================== */
/* ========================================================================== */
void apply_convolution_lut(uint8_t input[IMG_HEIGHT_TOTAL][IMG_WIDTH_TOTAL],
                           uint8_t output[IMG_HEIGHT_USEFUL][IMG_WIDTH_USEFUL],
                           const uint8_t filter_idx[3][3])
{
    for (int i = 1; i < IMG_HEIGHT_TOTAL - 1; i++) {
        for (int j = 1; j < IMG_WIDTH_TOTAL - 1; j++) {

            int out_i = i - 1;
            int out_j = j - 1;

            if (out_i >= IMG_HEIGHT_USEFUL || out_j >= IMG_WIDTH_USEFUL) {
                continue;
            }

            int sum = 0;

            for (int ki = -1; ki <= 1; ki++) {
                for (int kj = -1; kj <= 1; kj++) {

                    uint8_t pixel = input[i + ki][j + kj];
                    uint8_t idx   = filter_idx[ki + 1][kj + 1];

                    sum += mul_lut[pixel][idx];
                }
            }

            /* Saturação */
            if (sum < 0)   sum = 0;
            if (sum > 255) sum = 255;

            output[out_i][out_j] = (uint8_t)sum;
        }
    }
}
/* USER CODE END 4 */

/**
  * @brief  This function is executed in case of error occurrence.
  * @retval None
  */
void Error_Handler(void)
{
    __disable_irq();
    while (1) {
    }
}

#ifdef USE_FULL_ASSERT
/**
  * @brief  Reports the name of the source file and the source line number
  *         where the assert_param error has occurred.
  * @param  file: pointer to the source file name
  * @param  line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t *file, uint32_t line)
{
    /* User can add his own implementation to report the file name and line
       number, ex: printf("Wrong parameters value: file %s on line %d\r\n",
       file, line) */
}
#endif /* USE_FULL_ASSERT */
