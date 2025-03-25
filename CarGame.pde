import processing.serial.*;

Serial port;
PImage shipImage;
float shipX, shipY;
float shipSpeedX = 0, shipSpeedY = 0;
float maxSpeed = 5;
float acceleration = 0.4;
float friction = 0.92;
float shipAngle = 0; // Корабль всегда направлен вверх

// Класс для астероидов
class Asteroid {
  PVector pos;
  float size; // Размер: 1 - маленький, 2 - средний, 3 - большой
  float speedX, speedY; // Скорость по X и Y

  Asteroid(float x, float y, float size, float speedX, float speedY) {
    this.pos = new PVector(x, y);
    this.size = size;
    this.speedX = speedX;
    this.speedY = speedY;
  }
}

// Класс для частиц взрыва
class Particle {
  PVector pos;
  PVector vel;
  float lifespan;

  Particle(float x, float y) {
    this.pos = new PVector(x, y);
    this.vel = PVector.random2D().mult(random(1, 3));
    this.lifespan = 255;
  }

  void update() {
    pos.add(vel);
    lifespan -= 5;
  }

  void display() {
    noStroke();
    fill(255, lifespan, 0, lifespan);
    ellipse(pos.x, pos.y, 5, 5);
  }

  boolean isDead() {
    return lifespan <= 0;
  }
}

ArrayList<Asteroid> asteroids = new ArrayList<Asteroid>();
float asteroidSpeed = 2;
float asteroidSpawnRate = 0.02;

ArrayList<PVector> bullets = new ArrayList<PVector>();
float bulletSpeed = 8;

ArrayList<PVector> stars = new ArrayList<PVector>();
ArrayList<Particle> particles = new ArrayList<Particle>(); // Список частиц для эффекта взрыва

int score = 0;
int superLaserPoints = 0;
boolean canUseSuperLaser = false;
boolean superLaserActive = false;
int superLaserTimer = 0;

boolean gameOver = false;

void setup() {
  size(800, 600);
  shipX = width / 2;
  shipY = height - 50;

  // Загружаем изображение корабля
  shipImage = loadImage("starship.png");

  for (int i = 0; i < 200; i++) {
    stars.add(new PVector(random(width), random(height), random(1, 3)));
  }

  String portName = "COM3";
  port = new Serial(this, portName, 9600);
  port.bufferUntil('\n');

  spawnAsteroid();
}

void draw() {
  if (gameOver) {
    displayGameOver();
    return;
  }

  background(0);
  drawStars();
  updateGameElements();
  drawAsteroids();
  drawBullets();
  drawParticles(); // Рисуем частицы
  checkCollisions();
  displayHUD();
}

void updateGameElements() {
  updateAsteroids();
  updateBullets();
  updateShip();
  updateParticles(); // Обновляем частицы
  
  if (superLaserActive) {
    superLaserTimer--;
    if (superLaserTimer <= 0) {
      superLaserActive = false;
    }
    drawSuperLaser();
  }
}

void updateShip() {
  if (!gameOver) {
    shipSpeedX *= friction;
    shipSpeedY *= friction;
    shipX = constrain(shipX + shipSpeedX, 30, width - 30);
    shipY = constrain(shipY + shipSpeedY, 30, height - 30);
  }

  drawShip();
}

void drawShip() {
  if (shipImage != null) {
    pushMatrix();
    translate(shipX, shipY);
    rotate(shipAngle);
    imageMode(CENTER);
    image(shipImage, 0, 0, 40, 40);
    popMatrix();
  } else {
    pushMatrix();
    translate(shipX, shipY);
    rotate(shipAngle);
    fill(150);
    triangle(0, -15, -15, 15, 15, 15);
    popMatrix();
  }
}

void drawAsteroids() {
  fill(150);
  for (int i = 0; i < asteroids.size(); i++) {
    Asteroid asteroid = asteroids.get(i);
    float diameter;
    if (asteroid.size == 3) diameter = 40; // Большой
    else if (asteroid.size == 2) diameter = 30; // Средний
    else diameter = 20; // Маленький
    ellipse(asteroid.pos.x, asteroid.pos.y, diameter, diameter);
  }
}

void drawBullets() {
  fill(255, 0, 0);
  for (int i = 0; i < bullets.size(); i++) {
    PVector bullet = bullets.get(i);
    rect(bullet.x - 2, bullet.y - 5, 4, 10);
  }
}

void drawParticles() {
  for (int i = particles.size() - 1; i >= 0; i--) {
    Particle p = particles.get(i);
    p.update();
    p.display();
    if (p.isDead()) {
      particles.remove(i);
    }
  }
}

void updateParticles() {
  for (int i = particles.size() - 1; i >= 0; i--) {
    Particle p = particles.get(i);
    p.update();
    if (p.isDead()) {
      particles.remove(i);
    }
  }
}

void serialEvent(Serial port) {
  String data = port.readStringUntil('\n');
  if (data != null) {
    data = trim(data);
    String[] values = split(data, ',');
    
    if (values.length == 4) {
      int xValue = int(values[0]);
      int yValue = int(values[1]);
      int joyButton = int(values[2]);
      int fireButton = int(values[3]);

      println("xValue: " + xValue + ", yValue: " + yValue + ", joyButton: " + joyButton + ", fireButton: " + fireButton);

      handleInput(xValue, yValue, joyButton, fireButton);
    }
  }
}

void handleInput(int xValue, int yValue, int joyButton, int fireButton) {
  if (gameOver) {
    if (joyButton == 1) resetGame();
    return;
  }

  float inputX = map(xValue, 0, 1023, -1, 1);
  float inputY = map(yValue, 0, 1023, -1, 1);
  inputY = -inputY;
  
  float magnitude = sqrt(inputX * inputX + inputY * inputY);
  if (magnitude > 0.2) {
    shipSpeedX = inputX * maxSpeed;
    shipSpeedY = inputY * maxSpeed;
  } else {
    shipSpeedX *= 0.9;
    shipSpeedY *= 0.9;
  }

  if (fireButton == 1) spawnBullet();
  if (joyButton == 1 && canUseSuperLaser) activateSuperLaser();
}

void updateBullets() {
  for (int i = bullets.size() - 1; i >= 0; i--) {
    PVector bullet = bullets.get(i);
    bullet.y -= bulletSpeed;
    
    if (bullet.y < -10) {
      bullets.remove(i);
    }
  }

  checkBulletCollisions();
}

void checkBulletCollisions() {
  for (int i = bullets.size() - 1; i >= 0; i--) {
    PVector bullet = bullets.get(i);
    boolean bulletHit = false;
    
    for (int j = asteroids.size() - 1; j >= 0; j--) {
      Asteroid asteroid = asteroids.get(j);
      float hitRadius = asteroid.size == 3 ? 20 : (asteroid.size == 2 ? 15 : 10);
      
      if (PVector.dist(bullet, asteroid.pos) < hitRadius) {
        bullets.remove(i);
        bulletHit = true;
        
        // Эффект взрыва
        for (int k = 0; k < 10; k++) {
          particles.add(new Particle(asteroid.pos.x, asteroid.pos.y));
        }
        
        // Деление астероида
        if (asteroid.size == 3) { // Большой делится на два средних
          asteroids.add(new Asteroid(asteroid.pos.x - 15, asteroid.pos.y, 2, -1, asteroidSpeed)); // Разлет влево
          asteroids.add(new Asteroid(asteroid.pos.x + 15, asteroid.pos.y, 2, 1, asteroidSpeed));  // Разлет вправо
          score += 10;
          superLaserPoints += 10;
        } else if (asteroid.size == 2) { // Средний делится на два маленьких
          asteroids.add(new Asteroid(asteroid.pos.x - 10, asteroid.pos.y, 1, -1.5, asteroidSpeed)); // Разлет влево
          asteroids.add(new Asteroid(asteroid.pos.x + 10, asteroid.pos.y, 1, 1.5, asteroidSpeed));  // Разлет вправо
          score += 5;
          superLaserPoints += 5;
        } else { // Маленький исчезает
          score += 3;
          superLaserPoints += 3;
        }
        asteroids.remove(j);
        
        if (superLaserPoints >= 200) canUseSuperLaser = true;
        break;
      }
    }
    
    if (bulletHit) {
      continue;
    }
  }
}

void updateAsteroids() {
  for (int i = asteroids.size() - 1; i >= 0; i--) {
    Asteroid asteroid = asteroids.get(i);
    asteroid.pos.x += asteroid.speedX;
    asteroid.pos.y += asteroid.speedY;
    
    // Ограничиваем движение астероидов по X
    if (asteroid.pos.x < 0 || asteroid.pos.x > width) {
      asteroid.speedX *= -1; // Отражение от краев
    }
    
    if (asteroid.pos.y > height + 20) {
      asteroids.remove(i);
    }
  }

  if (random(1) < asteroidSpawnRate) spawnAsteroid();
}

void spawnAsteroid() {
  float size = random(1, 4);
  if (size < 2) size = 1; // 33% шанс на маленький
  else if (size < 3) size = 2; // 33% шанс на средний
  else size = 3; // 33% шанс на большой
  
  asteroids.add(new Asteroid(random(50, width-50), -20, size, 0, asteroidSpeed));
}

void spawnBullet() {
  PVector bullet = new PVector(shipX, shipY - 15);
  bullets.add(bullet);
}

void activateSuperLaser() {
  superLaserActive = true;
  superLaserTimer = 30;
  superLaserPoints = 0;
  canUseSuperLaser = false;
}

void drawSuperLaser() {
  pushMatrix();
  translate(shipX, shipY);
  rotate(shipAngle);
  fill(0, 255, 255, 150);
  rect(-25, -height, 50, height);
  popMatrix();

  for (int i = asteroids.size() - 1; i >= 0; i--) {
    Asteroid asteroid = asteroids.get(i);
    if (asteroid.pos.x >= shipX - 25 && asteroid.pos.x <= shipX + 25 && asteroid.pos.y >= 0 && asteroid.pos.y <= shipY) {
      // Эффект взрыва
      for (int k = 0; k < 10; k++) {
        particles.add(new Particle(asteroid.pos.x, asteroid.pos.y));
      }
      
      // Деление астероида
      if (asteroid.size == 3) {
        asteroids.add(new Asteroid(asteroid.pos.x - 15, asteroid.pos.y, 2, -1, asteroidSpeed));
        asteroids.add(new Asteroid(asteroid.pos.x + 15, asteroid.pos.y, 2, 1, asteroidSpeed));
        score += 10;
        superLaserPoints += 10;
      } else if (asteroid.size == 2) {
        asteroids.add(new Asteroid(asteroid.pos.x - 10, asteroid.pos.y, 1, -1.5, asteroidSpeed));
        asteroids.add(new Asteroid(asteroid.pos.x + 10, asteroid.pos.y, 1, 1.5, asteroidSpeed));
        score += 5;
        superLaserPoints += 5;
      } else {
        score += 3;
        superLaserPoints += 3;
      }
      asteroids.remove(i);
      if (superLaserPoints >= 200) canUseSuperLaser = true;
    }
  }
}

void checkCollisions() {
  for (int i = 0; i < asteroids.size(); i++) {
    Asteroid asteroid = asteroids.get(i);
    float hitRadius = asteroid.size == 3 ? 20 : (asteroid.size == 2 ? 15 : 10);
    if (PVector.dist(new PVector(shipX, shipY), asteroid.pos) < hitRadius + 15) {
      gameOver = true;
      return;
    }
  }
}

void displayHUD() {
  fill(255);
  textSize(20);
  textAlign(LEFT);
  text("Score: " + score, 10, 30);
  text("Super Laser: " + superLaserPoints + "/200", 10, 60);
  if (canUseSuperLaser) {
    fill(0, 255, 0);
    text("Super Laser Ready!", 10, 90);
  }
}

void displayGameOver() {
  background(0);
  drawStars();
  
  fill(255);
  textSize(40);
  textAlign(CENTER, CENTER);
  text("Game Over!", width/2, height/2);
  text("Score: " + score, width/2, height/2 + 50);
  textSize(20);
  text("Press joystick button to restart", width/2, height/2 + 100);
  
  textAlign(LEFT);
}

void resetGame() {
  shipX = width/2;
  shipY = height-50;
  shipSpeedX = 0;
  shipSpeedY = 0;
  shipAngle = 0;
  asteroids.clear();
  bullets.clear();
  particles.clear(); // Очищаем частицы
  score = 0;
  superLaserPoints = 0;
  canUseSuperLaser = false;
  superLaserActive = false;
  gameOver = false;
  spawnAsteroid();
}

void drawStars() {
  fill(255);
  for (int i = 0; i < stars.size(); i++) {
    PVector star = stars.get(i);
    ellipse(star.x, star.y, star.z, star.z);
  }
}
