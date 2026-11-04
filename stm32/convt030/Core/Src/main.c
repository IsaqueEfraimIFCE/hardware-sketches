/* USER CODE BEGIN Header */
/* USER CODE END Header */
/* Includes ------------------------------------------------------------------*/
#include "main.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */
/* USER CODE END Includes */

/* Private typedef -----------------------------------------------------------*/
/* USER CODE BEGIN PTD */
/* USER CODE END PTD */

/* Private define ------------------------------------------------------------*/
/* USER CODE BEGIN PD */
#define IMG_WIDTH_TOTAL  10
#define IMG_HEIGHT_TOTAL 10

/**
 * @brief Dimensão útil da imagem onde a convolução é aplicada (8×8 pixels).
 */
#define IMG_WIDTH_USEFUL 8
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
TIM_HandleTypeDef htim3;

UART_HandleTypeDef huart2;

/* USER CODE BEGIN PV */
uint8_t rx_buffer[BLOCK_RX_SIZE];

/**
 * @brief Buffer de transmissão contendo imagem filtrada 8×8.
 */
uint8_t tx_buffer[BLOCK_TX_SIZE];

/**
 * @brief Sequência de reconhecimento (ACK). Enviada antes e depois de cada bloco.
 */
uint8_t ack[2] = {0xAA, 0x55};

/**
 * @brief Kernel 3×3 utilizado no processamento.
 */
const int Filter[3][3] = {
    {-1, 0, 1},
    {-2, 0, 2},
    {-1, 0, 1}
};
uint32_t t_start, t_end, t_exec_us;
int16_t LUT_M2[256];
int16_t LUT_M1[256];
int16_t LUT_0[256];
int16_t LUT_P1[256];
int16_t LUT_P2[256];
void init_luts(void)
{
    for (int i = 0; i < 256; i++) {
        LUT_M2[i] = -2 * i;
        LUT_M1[i] = -1 * i;
        LUT_0[i]  =  0;
        LUT_P1[i] =  i;
        LUT_P2[i] =  2 * i;
    }
}
static inline const int16_t* get_lut(int8_t k)
{
    switch (k) {
        case -2: return LUT_M2;
        case -1: return LUT_M1;
        case  0: return LUT_0;
        case  1: return LUT_P1;
        case  2: return LUT_P2;
        default: return LUT_0; // segurança
    }
}

/**
 * @brief Inicializa a LUT de multiplicação pixel × peso.
 */

/* USER CODE END PV */

/* Private function prototypes -----------------------------------------------*/
void SystemClock_Config(void);
static void MX_GPIO_Init(void);
static void MX_USART2_UART_Init(void);
static void MX_TIM3_Init(void);
/* USER CODE BEGIN PFP */
void apply_convolution(uint8_t input[IMG_HEIGHT_TOTAL][IMG_WIDTH_TOTAL],
                       uint8_t output[IMG_HEIGHT_USEFUL][IMG_WIDTH_USEFUL],
                       const int filter[3][3]);

/* USER CODE END PFP */

/* Private user code ---------------------------------------------------------*/
/* USER CODE BEGIN 0 */
/* USER CODE END 0 */

/**
  * @brief  The application entry point.
  * @retval int
  */

/**
  * @brief System Clock Configuration
  * @retval None
  */
void SystemClock_Config(void)
{
  RCC_OscInitTypeDef RCC_OscInitStruct = {0};
  RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

  /** Initializes the RCC Oscillators according to the specified parameters
  * in the RCC_OscInitTypeDef structure.
  */
  RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSI;
  RCC_OscInitStruct.HSIState = RCC_HSI_ON;
  RCC_OscInitStruct.HSICalibrationValue = RCC_HSICALIBRATION_DEFAULT;
  RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
  RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSI;
  RCC_OscInitStruct.PLL.PLLMUL = RCC_PLL_MUL12;
  RCC_OscInitStruct.PLL.PREDIV = RCC_PREDIV_DIV1;
  if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
  {
    Error_Handler();
  }

  /** Initializes the CPU, AHB and APB buses clocks
  */
  RCC_ClkInitStruct.ClockType = RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_SYSCLK
                              |RCC_CLOCKTYPE_PCLK1;
  RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
  RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
  RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV1;

  if (HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_1) != HAL_OK)
  {
    Error_Handler();
  }
}

/**
  * @brief TIM3 Initialization Function
  * @param None
  * @retval None
  */
static void MX_TIM3_Init(void)
{

  /* USER CODE BEGIN TIM3_Init 0 */
  /* USER CODE END TIM3_Init 0 */

  TIM_ClockConfigTypeDef sClockSourceConfig = {0};
  TIM_MasterConfigTypeDef sMasterConfig = {0};

  /* USER CODE BEGIN TIM3_Init 1 */
  /* USER CODE END TIM3_Init 1 */
  htim3.Instance = TIM3;
  htim3.Init.Prescaler = 47;
  htim3.Init.CounterMode = TIM_COUNTERMODE_UP;
  htim3.Init.Period = 65535;
  htim3.Init.ClockDivision = TIM_CLOCKDIVISION_DIV1;
  htim3.Init.AutoReloadPreload = TIM_AUTORELOAD_PRELOAD_DISABLE;
  if (HAL_TIM_Base_Init(&htim3) != HAL_OK)
  {
    Error_Handler();
  }
  sClockSourceConfig.ClockSource = TIM_CLOCKSOURCE_INTERNAL;
  if (HAL_TIM_ConfigClockSource(&htim3, &sClockSourceConfig) != HAL_OK)
  {
    Error_Handler();
  }
  sMasterConfig.MasterOutputTrigger = TIM_TRGO_RESET;
  sMasterConfig.MasterSlaveMode = TIM_MASTERSLAVEMODE_DISABLE;
  if (HAL_TIMEx_MasterConfigSynchronization(&htim3, &sMasterConfig) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN TIM3_Init 2 */
  /* USER CODE END TIM3_Init 2 */

}

/**
  * @brief USART2 Initialization Function
  * @param None
  * @retval None
  */
static void MX_USART2_UART_Init(void)
{

  /* USER CODE BEGIN USART2_Init 0 */
  /* USER CODE END USART2_Init 0 */

  /* USER CODE BEGIN USART2_Init 1 */
  /* USER CODE END USART2_Init 1 */
  huart2.Instance = USART2;
  huart2.Init.BaudRate = 38400;
  huart2.Init.WordLength = UART_WORDLENGTH_8B;
  huart2.Init.StopBits = UART_STOPBITS_1;
  huart2.Init.Parity = UART_PARITY_NONE;
  huart2.Init.Mode = UART_MODE_TX_RX;
  huart2.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart2.Init.OverSampling = UART_OVERSAMPLING_16;
  huart2.Init.OneBitSampling = UART_ONE_BIT_SAMPLE_DISABLE;
  huart2.AdvancedInit.AdvFeatureInit = UART_ADVFEATURE_NO_INIT;
  if (HAL_UART_Init(&huart2) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN USART2_Init 2 */
  /* USER CODE END USART2_Init 2 */

}

/**
  * @brief GPIO Initialization Function
  * @param None
  * @retval None
  */
static void MX_GPIO_Init(void)
{
  GPIO_InitTypeDef GPIO_InitStruct = {0};
  /* USER CODE BEGIN MX_GPIO_Init_1 */
  /* USER CODE END MX_GPIO_Init_1 */

  /* GPIO Ports Clock Enable */
  __HAL_RCC_GPIOC_CLK_ENABLE();
  __HAL_RCC_GPIOF_CLK_ENABLE();
  __HAL_RCC_GPIOA_CLK_ENABLE();

  /*Configure GPIO pin Output Level */
  HAL_GPIO_WritePin(LD2_GPIO_Port, LD2_Pin, GPIO_PIN_RESET);

  /*Configure GPIO pin : B1_Pin */
  GPIO_InitStruct.Pin = B1_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_IT_FALLING;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  HAL_GPIO_Init(B1_GPIO_Port, &GPIO_InitStruct);

  /*Configure GPIO pin : LD2_Pin */
  GPIO_InitStruct.Pin = LD2_Pin;
  GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
  GPIO_InitStruct.Pull = GPIO_NOPULL;
  GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(LD2_GPIO_Port, &GPIO_InitStruct);

  /* USER CODE BEGIN MX_GPIO_Init_2 */
  /* USER CODE END MX_GPIO_Init_2 */
}

/* USER CODE BEGIN 4 */

void apply_convolution_lut(uint8_t input[IMG_HEIGHT_TOTAL][IMG_WIDTH_TOTAL],
                           uint8_t output[IMG_HEIGHT_USEFUL][IMG_WIDTH_USEFUL],
                           const int8_t filter[3][3])
{
    const int16_t* lut00 = get_lut(filter[0][0]);
    const int16_t* lut01 = get_lut(filter[0][1]);
    const int16_t* lut02 = get_lut(filter[0][2]);

    const int16_t* lut10 = get_lut(filter[1][0]);
    const int16_t* lut11 = get_lut(filter[1][1]);
    const int16_t* lut12 = get_lut(filter[1][2]);

    const int16_t* lut20 = get_lut(filter[2][0]);
    const int16_t* lut21 = get_lut(filter[2][1]);
    const int16_t* lut22 = get_lut(filter[2][2]);

    for (int i = 1; i <= IMG_HEIGHT_USEFUL; i++) {
        for (int j = 1; j <= IMG_WIDTH_USEFUL; j++) {

            int32_t sum = 0;

            sum += lut00[input[i-1][j-1]];
            sum += lut01[input[i-1][j  ]];
            sum += lut02[input[i-1][j+1]];

            sum += lut10[input[i  ][j-1]];
            sum += lut11[input[i  ][j  ]];
            sum += lut12[input[i  ][j+1]];

            sum += lut20[input[i+1][j-1]];
            sum += lut21[input[i+1][j  ]];
            sum += lut22[input[i+1][j+1]];

            /* Saturação */
            if (sum < 0)   sum = 0;
            if (sum > 255) sum = 255;

            output[i-1][j-1] = (uint8_t)sum;
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
  /* USER CODE BEGIN Error_Handler_Debug */
  /* USER CODE END Error_Handler_Debug */
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
  /* USER CODE BEGIN 6 */
  /* USER CODE END 6 */
}
#endif /* USE_FULL_ASSERT */
