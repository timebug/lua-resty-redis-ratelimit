import { useEffect, useCallback } from 'react';
import { useInterval } from 'usehooks-ts';
import { useGameStore } from '../store/useGameStore';
import { GRID_SIZE, MIN_SPEED, Position } from '../types';

const getRandomPosition = (snake: Position[]): Position => {
  let newPos: Position;
  while (true) {
    newPos = {
      x: Math.floor(Math.random() * GRID_SIZE),
      y: Math.floor(Math.random() * GRID_SIZE),
    };
    const onSnake = snake.some(segment => segment.x === newPos.x && segment.y === newPos.y);
    if (!onSnake) break;
  }
  return newPos;
};

export const useSnakeGame = () => {
  const {
    snake,
    food,
    direction,
    nextDirection,
    status,
    speed,
    score,
    setSnake,
    setFood,
    setDirection,
    setNextDirection,
    setScore,
    setSpeed,
    gameOver,
  } = useGameStore();

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', ' '].includes(e.key)) {
        e.preventDefault();
      }

      const state = useGameStore.getState();
      if (state.status !== 'PLAYING') {
        if (e.key === ' ' && state.status !== 'GAME_OVER') {
             state.status === 'IDLE' ? state.startGame() : state.pauseGame();
        }
        return;
      }

      const currentNext = state.nextDirection;
      
      // Prevent reversing into the current planned direction
      switch (e.key) {
        case 'ArrowUp':
          if (currentNext !== 'DOWN') setNextDirection('UP');
          break;
        case 'ArrowDown':
          if (currentNext !== 'UP') setNextDirection('DOWN');
          break;
        case 'ArrowLeft':
          if (currentNext !== 'RIGHT') setNextDirection('LEFT');
          break;
        case 'ArrowRight':
          if (currentNext !== 'LEFT') setNextDirection('RIGHT');
          break;
        case ' ':
          state.pauseGame();
          break;
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [setNextDirection]);

  const moveSnake = useCallback(() => {
    if (status !== 'PLAYING') return;

    // Commit the buffered direction
    setDirection(nextDirection);
    
    const head = snake[0];
    const newHead = { ...head };

    switch (nextDirection) {
      case 'UP': newHead.y -= 1; break;
      case 'DOWN': newHead.y += 1; break;
      case 'LEFT': newHead.x -= 1; break;
      case 'RIGHT': newHead.x += 1; break;
    }

    // Check Wall Collision
    if (
      newHead.x < 0 ||
      newHead.x >= GRID_SIZE ||
      newHead.y < 0 ||
      newHead.y >= GRID_SIZE
    ) {
      gameOver();
      return;
    }

    // Check Self Collision (excluding the tail which will move, unless we grow)
    // If we grow, tail stays. If we don't, tail moves.
    // Simplest is to check all, but that forbids chasing tail perfectly.
    // For now, check all is safe.
    if (snake.some(segment => segment.x === newHead.x && segment.y === newHead.y)) {
      gameOver();
      return;
    }

    let newSnake = [newHead, ...snake];
    let ateFood = false;

    // Check Food Collision
    if (newHead.x === food.x && newHead.y === food.y) {
      ateFood = true;
      setScore(score + 10);
      setFood(getRandomPosition(newSnake));
      setSpeed(Math.max(MIN_SPEED, speed - 2));
    } else {
      newSnake.pop();
    }

    setSnake(newSnake);
  }, [snake, nextDirection, status, food, score, speed, setSnake, setFood, setScore, setSpeed, setDirection, gameOver]);

  useInterval(
    moveSnake,
    status === 'PLAYING' ? speed : null
  );
};
