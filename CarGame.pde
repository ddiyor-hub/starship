import processing.serial.*;

Serial port;
PImage shipImage;
PImage bossImage;
PImage asteroidImage;
float shipX, shipY;
float shipSpeedX = 0, shipSpeedY = 0;
float maxSpeed = 5;
float acceleration = 0.4;
float friction = 0.92;
float shipAngle = 0;

int shipLives = 10;
boolean bossActive = false;
Boss boss;
boolean paused = false;
boolean gameStarted = false;
boolean gameOver = false;
boolean gameWon = false;
int highScore = 0;

class Asteroid {
  PVector pos;
  float size;
  float speedX, speedY;

  Asteroid(float x, float y, float size, float speedX, float speedY) {
    this.pos = new PVector(x, y);
    this.size = size;
    this.speedX = speedX;
    this.speedY = speedY;
  }
}

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

class Boss {
  PVector pos;
  float health = 300;
  float speed = 3.5;
  int shootTimer = 90;
  int phase = 1;
  float targetX, targetY;
  int laserTimer = 200;
  int minionTimer = 300;
  int shockwaveTimer = -1;
  float dodgeChance = 0.3;
  int bulletCount = 0;
  int moveTimer = 0;
  int fightTime = 0;

  Boss(float x, float y) {
    this.pos = new PVector(x, y);
    this.targetX = x;
    this.targetY = y;
  }

  void update() {
    fightTime++;

    moveTimer--;
    if (moveTimer <= 0) {
      updateTarget();
      moveTimer = int(random(60, 120));
    }
    pos.x = lerp(pos.x, targetX, 0.05);
    pos.y = lerp(pos.y, targetY, 0.05);
    pos.x = constrain(pos.x, 100, width - 100);
    pos.y = constrain(pos.y, 50, height / 2);

    dodgeBullets();

    shootTimer--;
    if (shootTimer <= 0) {
      shoot();
      shootTimer = int(random(60, 120));
    }
    laserTimer--;
    if (laserTimer <= 0) {
      laserAttack();
      laserTimer = 200;
    }
    minionTimer--;
    if (phase >= 2 && minionTimer <= 0) {
      spawnMinions();
      minionTimer = 300;
    }
    if (health <= 100 && shockwaveTimer == -1) {
      shockwaveAttack();
      shockwaveTimer = 0;
    }

    if (health <= 150 && phase == 1) {
      phase = 2;
      speed *= 1.5;
    }
    if ((health <= 50 || fightTime >= 3600) && phase == 2) {
      phase = 3;
      speed *= 1.2;
      dodgeChance = 0.7;
    }
  }

  void updateTarget() {
    if (PVector.dist(new PVector(shipX, shipY), pos) < 150) {
      targetX = shipX > pos.x ? pos.x - random(150, 250) : pos.x + random(150, 250);
      targetY = pos.y + random(-50, 50);
    } else if (bulletCount > 20) {
      targetX = random(100, width - 100);
      targetY = random(50, height / 2);
    } else {
      targetX = shipX + (shipX < pos.x ? random(-150, -100) : random(100, 150));
      targetY = shipY - random(100, 200);
    }
  }

  void dodgeBullets() {
    for (PVector bullet : bullets) {
      float dist = PVector.dist(bullet, pos);
      if (dist < 150) {
        bulletCount++;
        if (random(1) < dodgeChance) {
          float bulletAngle = atan2(bullet.y - pos.y, bullet.x - pos.x);
          targetX = pos.x - cos(bulletAngle) * 100;
          targetY = pos.y - sin(bulletAngle) * 50;
          dodgeChance = min(dodgeChance + 0.05, 0.9);
          break;
        }
      }
    }
    if (bulletCount > 0 && frameCount % 300 == 0) bulletCount = max(bulletCount - 5, 0);
  }

  void shoot() {
    float angleToShip = atan2(shipY - pos.y, shipX - pos.x);
    float bulletSpeed = phase == 1 ? 5 : 6;
    float distToShip = PVector.dist(new PVector(shipX, shipY), pos);

    if (distToShip > 300) {
      for (int i = 0; i < 5; i++) {
        float spread = random(-0.2, 0.2);
        asteroids.add(new Asteroid(pos.x, pos.y + 50, 1, cos(angleToShip + spread) * bulletSpeed, sin(angleToShip + spread) * bulletSpeed));
      }
    } else if (distToShip < 150) {
      asteroids.add(new Asteroid(pos.x, pos.y + 50, 1, cos(angleToShip) * bulletSpeed * 1.5, sin(angleToShip) * bulletSpeed * 1.5));
    } else if (phase >= 2) {
      for (int i = -2; i <= 2; i++) {
        asteroids.add(new Asteroid(pos.x, pos.y + 50, 1, cos(angleToShip + i * 0.3) * bulletSpeed, sin(angleToShip + i * 0.3) * bulletSpeed));
      }
    } else {
      asteroids.add(new Asteroid(pos.x, pos.y + 50, 1, cos(angleToShip - 0.3) * bulletSpeed, sin(angleToShip - 0.3) * bulletSpeed));
      asteroids.add(new Asteroid(pos.x, pos.y + 50, 1, cos(angleToShip) * bulletSpeed, sin(angleToShip) * bulletSpeed));
      asteroids.add(new Asteroid(pos.x, pos.y + 50, 1, cos(angleToShip + 0.3) * bulletSpeed, sin(angleToShip + 0.3) * bulletSpeed));
    }
  }

  void laserAttack() {
    asteroids.add(new Asteroid(pos.x, pos.y + 50, 2, (shipX - pos.x) * 0.02, 8));
  }

  void spawnMinions() {
    for (int i = 0; i < 3; i++) {
      asteroids.add(new Asteroid(pos.x + random(-50, 50), pos.y + 50, 1, (shipX - pos.x) * 0.01, 4));
    }
  }

  void shockwaveAttack() {
    for (int i = 0; i < 12; i++) {
      float angle = i * TWO_PI / 12;
      asteroids.add(new Asteroid(pos.x, pos.y, 1, cos(angle) * 5, sin(angle) * 5));
    }
  }

  void display() {
    if (bossImage != null) {
      pushMatrix();
      translate(pos.x, pos.y);
      imageMode(CENTER);
      image(bossImage, 0, 0, 100, 60);
      popMatrix();
    } else {
      fill(255, 0, 0);
      rect(pos.x - 50, pos.y - 30, 100, 60);
    }
    if (phase >= 2) {
      fill(255, 0, 0, 150);
      ellipse(pos.x, pos.y, 120, 120);
    }
    if (laserTimer < 30) {
      stroke(255, 0, 0);
      line(pos.x, pos.y, shipX, shipY);
      noStroke();
    }
    fill(255);
    textAlign(CENTER);
    text("BOSS HP: " + int(health), pos.x, pos.y - 40);
  }
}

ArrayList<Asteroid> asteroids = new ArrayList<Asteroid>();
float asteroidSpeed = 2;
float asteroidSpawnRate = 0.02;

ArrayList<PVector> bullets = new ArrayList<PVector>();
float bulletSpeed = 8;

ArrayList<PVector> stars = new ArrayList<PVector>();
ArrayList<Particle> particles = new ArrayList<Particle>();

int score = 0;
int superLaserPoints = 0;
boolean canUseSuperLaser = false;
boolean superLaserActive = false;
int superLaserTimer = 0;

void setup() {
  size(800, 600);
  shipX = width / 2;
  shipY = height - 50;
  shipLives = 10;
  bossActive = false;

  shipImage = loadImage("starship.png");
  bossImage = loadImage("boss1.png");
  asteroidImage = loadImage("asteroid1.png");

  for (int i = 0; i < 200; i++) {
    stars.add(new PVector(random(width), random(height), random(1, 3)));
  }

  String portName = "COM3";
  try {
    port = new Serial(this, portName, 9600);
    port.bufferUntil('\n');
  } catch (Exception e) {
    println("Error initializing serial port: " + e.getMessage());
  }
}

void draw() {
  background(0);
  drawStars();

  if (!gameStarted) {
    displayStartScreen();
  } else if (gameOver) {
    displayGameOver();
  } else if (gameWon) {
    displayVictoryScreen();
  } else {
    if (!paused) {
      updateGameElements();
      checkCollisions();
    }

    drawAsteroids();
    drawBullets();
    drawParticles();
    if (bossActive && boss != null) {
      boss.display();
    }
    drawShip();

    if (paused) {
      displayPaused();
    }

    displayHUD();
  }
}

void displayStartScreen() {
  fill(255);
  textSize(40);
  textAlign(CENTER, CENTER);
  text("Space Shooter", width/2, height/2 - 50);
  textSize(20);
  text("Press ENTER to Start", width/2, height/2 + 50);
  text("High Score: " + highScore, width/2, height/2 + 100);
}

void displayVictoryScreen() {
  background(0);
  drawStars();
  fill(0, 255, 0);
  textSize(40);
  textAlign(CENTER, CENTER);
  text("Victory!", width/2, height/2 - 50);
  fill(255);
  textSize(20);
  text("Score: " + score, width/2, height/2);
  text("High Score: " + highScore, width/2, height/2 + 30);
  text("Press joystick button to restart", width/2, height/2 + 70);
  textAlign(LEFT);

  if (score > highScore) {
    highScore = score;
  }
}

void updateGameElements() {
  updateAsteroids();
  updateBullets();
  updateShip();
  updateParticles();

  if (score >= 500 && !bossActive) {
    boss = new Boss(width/2, 100);
    bossActive = true;
    asteroids.clear();
  }

  if (bossActive && boss != null) {
    boss.update();
  }

  if (superLaserActive) {
    superLaserTimer--;
    if (superLaserTimer <= 0) {
      superLaserActive = false;
    }
    drawSuperLaser();
  }
}

void updateShip() {
  if (!gameOver && !gameWon) {
    shipSpeedX *= friction;
    shipSpeedY *= friction;
    shipX = constrain(shipX + shipSpeedX, 30, width - 30);
    shipY = constrain(shipY + shipSpeedY, 30, height - 30);
  }
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
  for (int i = 0; i < asteroids.size(); i++) {
    Asteroid asteroid = asteroids.get(i);
    float diameter = asteroid.size == 3 ? 40 : (asteroid.size == 2 ? 30 : 20);
    
    if (asteroidImage != null) {
      pushMatrix();
      translate(asteroid.pos.x, asteroid.pos.y);
      imageMode(CENTER);
      image(asteroidImage, 0, 0, diameter, diameter);
      popMatrix();
    } else {
      fill(150);
      ellipse(asteroid.pos.x, asteroid.pos.y, diameter, diameter);
    }
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
    p.display();
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
      handleInput(xValue, yValue, joyButton, fireButton);
    }
  }
}

void handleInput(int xValue, int yValue, int joyButton, int fireButton) {
  if (gameOver || gameWon) {
    if (joyButton == 1) resetGame();
    return;
  }

  if (!paused && gameStarted) {
    float inputX = map(xValue, 0, 1023, -1, 1);
    float inputY = map(yValue, 0, 1023, -1, 1);

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
  ArrayList<Integer> bulletsToRemove = new ArrayList<Integer>();
  ArrayList<Integer> asteroidsToRemove = new ArrayList<Integer>();
  ArrayList<Asteroid> newAsteroids = new ArrayList<Asteroid>();

  for (int i = bullets.size() - 1; i >= 0; i--) {
    PVector bullet = bullets.get(i);
    boolean bulletHit = false;

    if (bossActive && boss != null) {
      if (bullet.x > boss.pos.x - 50 && bullet.x < boss.pos.x + 50 &&
          bullet.y > boss.pos.y - 30 && bullet.y < boss.pos.y + 30) {
        bulletsToRemove.add(i);
        boss.health -= 5;
        for (int k = 0; k < 10; k++) {
          particles.add(new Particle(bullet.x, bullet.y));
        }
        score += 10;
        if (boss.health <= 0) {
          bossActive = false;
          boss = null;
          score += 200;
          for (int k = 0; k < 50; k++) {
            particles.add(new Particle(bullet.x, bullet.y));
          }
          gameWon = true;
        }
        continue;
      }
    }

    for (int j = asteroids.size() - 1; j >= 0; j--) {
      Asteroid asteroid = asteroids.get(j);
      float hitRadius = asteroid.size == 3 ? 20 : (asteroid.size == 2 ? 15 : 10);
      if (PVector.dist(bullet, asteroid.pos) < hitRadius) {
        bulletsToRemove.add(i);
        asteroidsToRemove.add(j);
        bulletHit = true;
        for (int k = 0; k < 10; k++) {
          particles.add(new Particle(asteroid.pos.x, asteroid.pos.y));
        }
        if (asteroid.size == 3) {
          newAsteroids.add(new Asteroid(asteroid.pos.x - 15, asteroid.pos.y, 2, -1, asteroidSpeed));
          newAsteroids.add(new Asteroid(asteroid.pos.x + 15, asteroid.pos.y, 2, 1, asteroidSpeed));
          score += 10;
          superLaserPoints += 10;
        } else if (asteroid.size == 2) {
          newAsteroids.add(new Asteroid(asteroid.pos.x - 10, asteroid.pos.y, 1, -1.5, asteroidSpeed));
          newAsteroids.add(new Asteroid(asteroid.pos.x + 10, asteroid.pos.y, 1, 1.5, asteroidSpeed));
          score += 5;
          superLaserPoints += 5;
        } else {
          score += 3;
          superLaserPoints += 3;
        }
        if (superLaserPoints >= 200) canUseSuperLaser = true;
        break;
      }
    }
  }

  for (int i : bulletsToRemove) {
    if (i >= 0 && i < bullets.size()) bullets.remove(i);
  }
  for (int j : asteroidsToRemove) {
    if (j >= 0 && j < asteroids.size()) asteroids.remove(j);
  }
  asteroids.addAll(newAsteroids);
}

void updateAsteroids() {
  for (int i = asteroids.size() - 1; i >= 0; i--) {
    Asteroid asteroid = asteroids.get(i);
    asteroid.pos.x += asteroid.speedX;
    asteroid.pos.y += asteroid.speedY;
    if (asteroid.pos.x < 0 || asteroid.pos.x > width) {
      asteroid.speedX *= -1;
    }
    if (asteroid.pos.y > height + 20) {
      asteroids.remove(i);
    }
  }

  if (!bossActive && !gameWon && random(1) < asteroidSpawnRate) spawnAsteroid();
}

void spawnAsteroid() {
  float size = random(1, 4);
  if (size < 2) size = 1;
  else if (size < 3) size = 2;
  else size = 3;
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
  if (bossActive && boss != null) {
    boss.targetX = boss.pos.x + (shipX < boss.pos.x ? -150 : 150);
    boss.targetY = boss.pos.y - 100;
  }
}

void drawSuperLaser() {
  pushMatrix();
  translate(shipX, shipY);
  rotate(shipAngle);

  // Внешнее свечение (широкое, слабое)
  noStroke();
  fill(0, 200, 255, 40);
  rect(-40, -height, 80, height + 20); // Более широкая область свечения

  // Средний слой (с мерцанием)
  for (int y = -height; y < 0; y += 5) {
    float noiseVal = noise(frameCount * 0.05 + y * 0.01); // Мерцание с помощью шума
    float flicker = map(noiseVal, 0, 1, 80, 120); // Изменение прозрачности
    fill(0, 220, 255, flicker);
    rect(-30, y, 60, 10);
  }

  // Яркое ядро луча
  fill(0, 255, 255, 200);
  rect(-15, -height, 30, height + 10);

  // Центральная белая линия (имитация интенсивного света)
  fill(255, 255, 255, 150);
  rect(-5, -height, 10, height + 5);

  popMatrix();

  // Добавляем частицы вдоль луча для динамики
  if (frameCount % 3 == 0) { // Реже создаем частицы для оптимизации
    for (int i = 0; i < 5; i++) {
      float particleX = shipX + random(-30, 30);
      float particleY = shipY - random(0, height);
      particles.add(new Particle(particleX, particleY));
    }
  }

  ArrayList<Integer> asteroidsToRemove = new ArrayList<Integer>();
  ArrayList<Asteroid> newAsteroids = new ArrayList<Asteroid>();

  if (bossActive && boss != null) {
    if (boss.pos.x >= shipX - 25 && boss.pos.x <= shipX + 25 && boss.pos.y <= shipY) {
      boss.health -= 20;
      for (int k = 0; k < 20; k++) {
        particles.add(new Particle(boss.pos.x, boss.pos.y));
      }
      if (boss.health <= 0) {
        bossActive = false;
        float lastBossX = boss.pos.x;
        float lastBossY = boss.pos.y;
        boss = null;
        score += 200;
        for (int k = 0; k < 50; k++) {
          particles.add(new Particle(lastBossX, lastBossY));
        }
        gameWon = true;
      }
    }
  }

  for (int i = asteroids.size() - 1; i >= 0; i--) {
    Asteroid asteroid = asteroids.get(i);
    if (asteroid.pos.x >= shipX - 25 && asteroid.pos.x <= shipX + 25 && asteroid.pos.y >= 0 && asteroid.pos.y <= shipY) {
      asteroidsToRemove.add(i);
      for (int k = 0; k < 10; k++) {
        particles.add(new Particle(asteroid.pos.x, asteroid.pos.y));
      }
      if (asteroid.size == 3) {
        newAsteroids.add(new Asteroid(asteroid.pos.x - 15, asteroid.pos.y, 2, -1, asteroidSpeed));
        newAsteroids.add(new Asteroid(asteroid.pos.x + 15, asteroid.pos.y, 2, 1, asteroidSpeed));
        score += 10;
        superLaserPoints += 10;
      } else if (asteroid.size == 2) {
        newAsteroids.add(new Asteroid(asteroid.pos.x - 10, asteroid.pos.y, 1, -1.5, asteroidSpeed));
        newAsteroids.add(new Asteroid(asteroid.pos.x + 10, asteroid.pos.y, 1, 1.5, asteroidSpeed));
        score += 5;
        superLaserPoints += 5;
      } else {
        score += 3;
        superLaserPoints += 3;
      }
      if (superLaserPoints >= 200) canUseSuperLaser = true;
    }
  }

  for (int i : asteroidsToRemove) {
    if (i >= 0 && i < asteroids.size()) asteroids.remove(i);
  }
  asteroids.addAll(newAsteroids);
}

void checkCollisions() {
  if (bossActive && boss != null) {
    if (PVector.dist(new PVector(shipX, shipY), boss.pos) < 65) {
      shipLives--;
      shipX = width/2;
      shipY = height-50;
      if (shipLives <= 0) gameOver = true;
    }
  }

  for (int i = asteroids.size() - 1; i >= 0; i--) {
    Asteroid asteroid = asteroids.get(i);
    float hitRadius = asteroid.size == 3 ? 20 : (asteroid.size == 2 ? 15 : 10);
    if (PVector.dist(new PVector(shipX, shipY), asteroid.pos) < hitRadius + 15) {
      shipLives--;
      asteroids.remove(i);
      shipX = width/2;
      shipY = height-50;
      if (shipLives <= 0) gameOver = true;
      break;
    }
  }
}

void displayHUD() {
  fill(255);
  textSize(20);
  textAlign(LEFT);
  text("Score: " + score, 10, 30);

  fill(255, 0, 0);
  for (int i = 0; i < shipLives; i++) {
    rect(10 + i * 15, 40, 10, 20);
  }

  text("Super Laser: " + superLaserPoints + "/200", 10, 80);
  if (canUseSuperLaser) {
    fill(0, 255, 0);
    text("Super Laser Ready!", 10, 110);
  }
}

void displayGameOver() {
  background(0);
  drawStars();
  fill(255);
  textSize(40);
  textAlign(CENTER, CENTER);
  text("Game Over!", width/2, height/2 - 50);
  textSize(20);
  text("Score: " + score, width/2, height/2);
  text("High Score: " + highScore, width/2, height/2 + 30);
  text("Press joystick button to restart", width/2, height/2 + 70);
  textAlign(LEFT);

  if (score > highScore) {
    highScore = score;
  }
}

void displayPaused() {
  fill(255, 100);
  textSize(40);
  textAlign(CENTER, CENTER);
  text("Paused", width/2, height/2);
  textSize(20);
  text("Press S to resume", width/2, height/2 + 50);
  textAlign(LEFT);
}

void resetGame() {
  shipX = width/2;
  shipY = height-50;
  shipSpeedX = 0;
  shipSpeedY = 0;
  shipAngle = 0;
  shipLives = 10;
  asteroids.clear();
  bullets.clear();
  particles.clear();
  score = 0;
  superLaserPoints = 0;
  canUseSuperLaser = false;
  superLaserActive = false;
  bossActive = false;
  boss = null;
  gameOver = false;
  gameWon = false;
  paused = false;
  gameStarted = false;
  spawnAsteroid();
}

void drawStars() {
  fill(255);
  for (int i = 0; i < stars.size(); i++) {
    PVector star = stars.get(i);
    ellipse(star.x, star.y, star.z, star.z);
  }
}

void keyPressed() {
  if (key == ENTER && !gameStarted) {
    gameStarted = true;
    resetGame();
    gameStarted = true;
  } else if (key == 's' || key == 'S') {
    if (gameStarted && !gameOver && !gameWon) {
      paused = !paused;
    }
  }
}
