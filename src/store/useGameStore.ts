import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { GameState, GRID_SIZE, INITIAL_SPEED, Position, Direction } from '../types';

interface GameStore extends GameState {
  setSnake: (snake: Position[]) => void;
  setFood: (food: Position) => void;
  setDirection: (direction: Direction) => void;
  setNextDirection: (direction: Direction) => void;
  setScore: (score: number) => void;
  setStatus: (status: GameState['status']) => void;
  setSpeed: (speed: number) => void;
  resetGame: () => void;
  startGame: () => void;
  pauseGame: () => void;
  gameOver: () => void;
}

const INITIAL_SNAKE: Position[] = [
  { x: 10, y: 10 },
  { x: 10, y: 11 },
  { x: 10, y: 12 },
];

const INITIAL_FOOD: Position = { x: 5, y: 5 };

export const useGameStore = create<GameStore>()(
  persist(
    (set, get) => ({
      snake: INITIAL_SNAKE,
      food: INITIAL_FOOD,
      direction: 'UP',
      nextDirection: 'UP',
      score: 0,
      highScore: 0,
      status: 'IDLE',
      speed: INITIAL_SPEED,

      setSnake: (snake) => set({ snake }),
      setFood: (food) => set({ food }),
      setDirection: (direction) => set({ direction }),
      setNextDirection: (nextDirection) => set({ nextDirection }),
      setScore: (score) => {
        const { highScore } = get();
        set({ score, highScore: Math.max(score, highScore) });
      },
      setStatus: (status) => set({ status }),
      setSpeed: (speed) => set({ speed }),

      resetGame: () => set({
        snake: INITIAL_SNAKE,
        food: INITIAL_FOOD, // In a real game, randomize this
        direction: 'UP',
        nextDirection: 'UP',
        score: 0,
        status: 'IDLE',
        speed: INITIAL_SPEED,
      }),

      startGame: () => set({ status: 'PLAYING' }),
      pauseGame: () => set((state) => ({ status: state.status === 'PLAYING' ? 'PAUSED' : 'PLAYING' })),
      gameOver: () => set({ status: 'GAME_OVER' }),
    }),
    {
      name: 'snake-storage',
      partialize: (state) => ({ highScore: state.highScore }), // Only persist high score
    }
  )
);
