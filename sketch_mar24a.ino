// Пины для джойстик
#define JOY_X A0
#define JOY_Y A1
#define JOY_SW 2

// Пин для кнопки нитро
#define NITRO_BUTTON 3

void setup() {
  // Настройка Serial для связи с компьютером
  Serial.begin(9600);

  // Настройка пинов
  pinMode(JOY_SW, INPUT_PULLUP); // Кнопка джойстика
  pinMode(NITRO_BUTTON, INPUT_PULLUP); // Кнопка нитро
}

void loop() {
  // Считываем данные с джойстика
  int xValue = analogRead(JOY_X); // 0-1023
  int yValue = analogRead(JOY_Y); // 0-1023
  int joyButton = !digitalRead(JOY_SW); // 1 - нажата, 0 - не нажата
  int nitroButton = !digitalRead(NITRO_BUTTON); // 1 - нажата, 0 - не нажата

  // Отправляем данные через Serial в формате: "X,Y,joyButton,nitroButton"
  Serial.print(xValue);
  Serial.print(",");
  Serial.print(yValue);
  Serial.print(",");
  Serial.print(joyButton);
  Serial.print(",");
  Serial.println(nitroButton);

  delay(100); // Задержка для стабильности
}