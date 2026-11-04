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
int main(void)
{

  /* USER CODE BEGIN 1 */

  /* USER CODE END 1 */

  /* MCU Configuration--------------------------------------------------------*/

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
  MX_TIM3_Init();
  HAL_TIM_Base_Start(&htim3);

  /* USER CODE BEGIN 2 */
  /* USER CODE END 2 */

  /* Infinite loop */
  /* USER CODE BEGIN WHILE */

    /* USER CODE END WHILE */

    /* USER CODE BEGIN 3 */
  while (1)
  {
      char msg[64];

      uint32_t t_start, t_end;
      uint32_t t_exec_us;
      uint32_t sum_us = 0;
      uint32_t min_us = 0xFFFFFFFF;
      uint32_t max_us = 0;

      uint8_t img_in[IMG_HEIGHT_TOTAL][IMG_WIDTH_TOTAL];
      uint8_t img_out[IMG_HEIGHT_USEFUL][IMG_WIDTH_USEFUL];

      /* Inicializa imagem uma única vez */
      for (int i = 0; i < IMG_HEIGHT_TOTAL; i++) {
          for (int j = 0; j < IMG_WIDTH_TOTAL; j++) {
              img_in[i][j] = i + j;
          }
      }

      /* Zera contador antes do teste */
      __HAL_TIM_SET_COUNTER(&htim3, 0);

      for (int k = 0; k < 1000; k++)
      {
          t_start = __HAL_TIM_GET_COUNTER(&htim3);

          apply_convolution_lut(img_in, img_out, Filter);

          t_end = __HAL_TIM_GET_COUNTER(&htim3);

          /* Trata overflow do timer (16 bits) */
          if (t_end >= t_start)
              t_exec_us = t_end - t_start;
          else
              t_exec_us = (0xFFFF - t_start) + t_end + 1;

          sum_us += t_exec_us;

          if (t_exec_us < min_us) min_us = t_exec_us;
          if (t_exec_us > max_us) max_us = t_exec_us;
      }

      uint32_t avg_us = sum_us / 1000;

      int len = snprintf(msg, sizeof(msg),
          "N=%d | AVG=%lu us | MIN=%lu us | MAX=%lu us\r\n",
          1000,
          (unsigned long)avg_us,
          (unsigned long)min_us,
          (unsigned long)max_us
      );

      HAL_UART_Transmit(
          &huart2,
          (uint8_t *)msg,
          len,
          HAL_MAX_DELAY
      );

      HAL_Delay(1000);
  }
  /* USER CODE END 3 */
}

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
  huart2.Init.BaudRate = 115200;
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
    for (int i = 1; i <= IMG_HEIGHT_USEFUL; i++) {
        for (int j = 1; j <= IMG_WIDTH_USEFUL; j++) {

            int32_t sum = 0;

            sum += input[i-1][j-1] * filter[0][0];
            sum += input[i-1][j  ] * filter[0][1];
            sum += input[i-1][j+1] * filter[0][2];

            sum += input[i  ][j-1] * filter[1][0];
            sum += input[i  ][j  ] * filter[1][1];
            sum += input[i  ][j+1] * filter[1][2];

            sum += input[i+1][j-1] * filter[2][0];
            sum += input[i+1][j  ] * filter[2][1];
            sum += input[i+1][j+1] * filter[2][2];

            if (sum < 0) sum = 0;
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
