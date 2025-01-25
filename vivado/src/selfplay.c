// Copyright (c) 2025 Stacey Campbell
// SPDX-License-Identifier: MIT

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <xparameters.h>
#include <netif/xadapter.h>
#include <lwip/tcp.h>
#include <lwip/priv/tcp_priv.h>
#include <lwip/init.h>
#include <xil_cache.h>
#include <xuartps.h>
#include <xtime_l.h>
#include "numbat.h"

#pragma GCC optimize ("O2")

extern board_t game[GAME_MAX];
extern uint32_t game_moves;

static const char *random_opening_string(void);

static void
newgame_init(void)
{
        killer_clear_table();
        trans_clear_table();
        q_trans_clear_table();
        uci_init();
        nm_init();
}

void
selfplay(void)
{
        int32_t round;
        uint32_t player_a_white;
        uint32_t mate, stalemate, fifty_move, insufficient;
        uint32_t key_hit;
        uint32_t move_count;
        uint32_t game_active;
        uint32_t game_index;
        char buffer[1024];
        char *p, *next;
        const char *opening;
        tune_t player_a_tune, player_b_tune;
        tc_t tc;
        board_t best_board;
        uint32_t player_a_win, player_b_win, draw;

        tc_fixed(&tc, 5);       // seconds per move
        numbat_random_score_mask(1); // random eval bit masK

        player_a_tune = nm_current_tune();
        player_b_tune = nm_current_tune();

        player_a_tune.nm_delta_mult = 0;
        player_b_tune.nm_delta_mult = 15;

        player_a_win = 0;
        player_b_win = 0;
        draw = 0;
        for (round = 0; round < 1; ++round)
        {
                newgame_init();
                opening = random_opening_string();
                if (strlen(opening) >= sizeof(buffer) - 1)
                {
                        printf("%s: problem, stopping (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                        while (1);
                }
                strcpy(buffer, opening);
                p = buffer;
                next = buffer;
                while ((p = strsep(&next, " ")) != 0)
                        if (uci_move(p))
                        {
                                xil_printf("%s: unkown uci move %s, stopping\n", __PRETTY_FUNCTION__, p);
                                while (1);
                        }
                if (game_moves == 0)
                {
                        printf("%s: problem, stopping (%s %d)\n", __PRETTY_FUNCTION__, __FILE__, __LINE__);
                        while (1);
                }
                player_a_white = numbat_random() % 2;
                printf("opening: %s\n", opening);
                if (player_a_white)
                        printf("player a white, player b black\n");
                else
                        printf("player b white, player a black\n");
                do
                {
                        game_index = game_moves - 1;
                        if ((game[game_index].white_to_move && player_a_white) || (!game[game_index].white_to_move && !player_a_white))
                                nm_tune(&player_a_tune);        // player a's move
                        else
                                nm_tune(&player_b_tune);        // player b's move
                        best_board = nm_top(&tc, 0, 0, 1);
                        numbat_write_board_basic(&best_board);
                        numbat_write_board_wait(&best_board, 0);
                        move_count = numbat_move_count();
                        numbat_status(0, 0, &mate, &stalemate, 0, &fifty_move, &insufficient, 0);
                        numbat_reset_all_moves();
                        game[game_moves] = best_board;
                        ++game_moves;
                        game_active = !mate && !stalemate && !fifty_move && !insufficient && move_count > 0;
                        numbat_print_board(&best_board, 1);
                        fen_print(&best_board);
                        printf("\n");
                        key_hit = ui_data_available();
                }
                while (!key_hit && game_active);
                if (mate)
                        if (best_board.white_to_move)
                                if (player_a_white)
                                        ++player_b_win;
                                else
                                        ++player_a_win;
                        else if (player_a_white)
                                ++player_a_win;
                        else
                                ++player_b_win;
                else
                        ++draw;
                printf("a win: %4d, b win: %4d, draw: %4d\n", player_a_win, player_b_win, draw);
        }
}

static const char *common_openings[] = {
        "a2a3 e7e5 b2b3 d7d5 c2c3 g8f6 d2d3 b8c6 e2e3 f8d6 f2f3 e8g8 g2g3",
        "b1c3 d7d5 e2e4 d5e4 f2f3",
        "c2c4 e7e5 g2g3 g8f6 f1g2 d7d5 c4d5 f6d5 g1f3 b8c6 d2d3",
        "c2c4 g8f6 g1f3 c7c6 b2b3 d7d5 c1b2 c8g4",
        "c2c4 g8f6 g1f3 e7e6 g2g3 a7a6 f1g2 b7b5",
        "c2c4 g8f6 g2g3 c7c6 g1f3 d7d5 b2b3 c8f5",
        "d2d4 b8c6 d4d5 c6b8 e2e4 g8f6 e4e5 f6g8",
        "d2d4 d7d5 c1f4 c7c5 e2e4 d5e4",
        "d2d4 d7d5 c2c4 c7c6 b1c3 g8f6 e2e3 e7e6 g1f3 b8d7 d1c2 b7b6 b2b3 c8b7 f1d3 f8e7 e1g1 e8g8 c1b2",
        "d2d4 d7d5 c2c4 c7c6 g1f3 g8f6 b1c3 d5c4",
        "d2d4 d7d5 c2c4 c7c6 g1f3 g8f6 b1c3 d5c4 a2a4",
        "d2d4 d7d5 c2c4 c7c6 g1f3 g8f6 b1c3 d5c4 a2a4 c8f5 e2e3 b8a6",
        "d2d4 d7d5 c2c4 c7c6 g1f3 g8f6 b1c3 d5c4 e2e4 b7b5 e4e5",
        "d2d4 d7d5 c2c4 c7c6 g1f3 g8f6 b1c3 e7e6 c1g5 b8d7 e2e3 d8a5 c4d5 f6d5",
        "d2d4 d7d5 c2c4 c7c6 g1f3 g8f6 e2e3 c8f5 c4d5 c6d5 b1c3 e7e6 f3e5 f6d7",
        "d2d4 d7d5 c2c4 d5c4 g1f3 a7a6 e2e3 c8g4 f1c4 e7e6 d4d5",
        "d2d4 d7d5 c2c4 d5c4 g1f3 a7a6 e2e4",
        "d2d4 d7d5 c2c4 d5c4 g1f3 e7e6",
        "d2d4 d7d5 c2c4 d5c4 g1f3 g8f6 e2e3 c8g4",
        "d2d4 d7d5 c2c4 d5c4 g1f3 g8f6 e2e3 e7e6 f1c4 c7c5 e1g1",
        "d2d4 d7d5 c2c4 d5c4 g1f3 g8f6 e2e3 e7e6 f1c4 c7c5 e1g1 a7a6 d1e2 b7b5 c4b3 c8b7 f1d1 b8d7 b1c3 f8d6",
        "d2d4 d7d5 c2c4 e7e5 d4e5 d5d4 g1f3 c7c5",
        "d2d4 d7d5 c2c4 e7e6 b1c3 c7c5 c4d5 c5d4",
        "d2d4 d7d5 c2c4 e7e6 b1c3 c7c5 c4d5 e6d5 e2e4",
        "d2d4 d7d5 c2c4 e7e6 b1c3 c7c6 g1f3 d5c4 g2g3",
        "d2d4 d7d5 c2c4 e7e6 b1c3 g8f6 c1g5 b8d7 e2e3 c7c6",
        "d2d4 d7d5 c2c4 e7e6 b1c3 g8f6 c1g5 c7c5 c4d5 d8b6",
        "d2d4 d7d5 c2c4 e7e6 b1c3 g8f6 c1g5 f8e7 e2e3 e8g8 g1f3 b8d7 a1c1 c7c6 f1d3 d5c4 d3c4 f6d5",
        "d2d4 d7d5 c2c4 e7e6 b1c3 g8f6 c1g5 f8e7 e2e3 e8g8 g1f3 b8d7 a1c1 c7c6 f1d3 d5c4 d3c4 f6d5 g5e7 d8e7 e1g1 d5c3 c1c3 e6e5",
        "d2d4 d7d5 c2c4 e7e6 g1f3 c7c5 c4d5 e6d5 c1g5",
        "d2d4 d7d5 c2c4 e7e6 g1f3 g8f6 e2e3 c7c6 b1d2 g7g6",
        "d2d4 d7d5 e2e4 d5e4 b1c3 c7c5",
        "d2d4 d7d5 e2e4 d5e4 b1c3 g8f6 f2f3 e7e5",
        "d2d4 d7d5 g1f3 g8f6 c2c4 e7e6 b1c3 f8e7 c1g5 e8g8 e2e3 b8d7 a1c1 c7c6 f1d3 d5c4 d3c4 f6d5 h2h4",
        "d2d4 d7d6 g1f3 g7g6 c2c4 f8g7 e2e4 c8g4",
        "d2d4 f7f5 c2c4 g7g6 b1c3 g8h6",
        "d2d4 f7f5 e2e4 f5e4 b1c3 g8f6 c1g5 g7g6 h2h4",
        "d2d4 f7f5 e2e4 f5e4 b1c3 g8f6 f2f3",
        "d2d4 g7g6 c2c4 f8g7 b1c3 d7d6",
        "d2d4 g7g6 c2c4 f8g7 b1c3 d7d6 e2e4 b8c6",
        "d2d4 g8f6 b1c3 d7d5 c1g5 c7c5 g5f6 g7f6 e2e4 d5e4 d4d5",
        "d2d4 g8f6 c2c4 c7c5 d4d5 b7b5 c1g5",
        "d2d4 g8f6 c2c4 c7c5 d4d5 b7b5 c4b5 a7a6 b5a6 c8a6 b1c3 d7d6 e2e4",
        "d2d4 g8f6 c2c4 c7c5 d4d5 b7b5 c4b5 a7a6 b5a6 c8a6 b1c3 d7d6 g1f3 g7g6 g2g3",
        "d2d4 g8f6 c2c4 c7c5 d4d5 b7b5 f2f3",
        "d2d4 g8f6 c2c4 c7c5 d4d5 e7e6 b1c3 e6d5 c4d5 d7d6 e2e4 g7g6 f2f4",
        "d2d4 g8f6 c2c4 d7d6 b1c3 c7c6",
        "d2d4 g8f6 c2c4 e7e5 d4e5 f6g4 e2e4 g4e5 f2f4 e5c6",
        "d2d4 g8f6 c2c4 e7e6 b1c3 d7d5 c1g5 f8e7 e2e3 h7h6 g5h4 e8g8 g1f3 f6e4 h4e7 d8e7 c4d5 e4c3 b2c3 e6d5 d1b3 e7d6",
        "d2d4 g8f6 c2c4 e7e6 b1c3 d7d5 c4d5 e6d5 c1g5 c7c6",
        "d2d4 g8f6 c2c4 e7e6 b1c3 f8b4 a2a3 b4c3 b2c3 c7c5 e2e3",
        "d2d4 g8f6 c2c4 e7e6 b1c3 f8b4 d1b3 c7c5 d4c5 b8c6 g1f3 f6e4 c1d2 e4c5 b3c2 f7f5 g2g3",
        "d2d4 g8f6 c2c4 e7e6 b1c3 f8b4 e2e3 c7c5",
        "d2d4 g8f6 c2c4 e7e6 b1c3 f8b4 e2e3 c7c5 f1d3 b8c6 a2a3 b4c3 b2c3 e8g8",
        "d2d4 g8f6 c2c4 e7e6 b1c3 f8b4 e2e3 e8g8",
        "d2d4 g8f6 c2c4 e7e6 b1c3 f8b4 e2e3 e8g8 f1d3",
        "d2d4 g8f6 c2c4 e7e6 b1c3 f8b4 e2e3 e8g8 f1d3 d7d5",
        "d2d4 g8f6 c2c4 e7e6 b1c3 f8b4 e2e3 f6e4 d1c2 f7f5 g1f3 b7b6 f1d3 c8b7",
        "d2d4 g8f6 c2c4 e7e6 b1c3 f8b4 f2f3 d7d5 a2a3 b4c3 b2c3 c7c5 c4d5 f6d5 d4c5",
        "d2d4 g8f6 c2c4 e7e6 g1f3 b7b6 b1c3 d7d5 c4d5 e6d5 c1g5 f8e7 e2e3 e8g8 f1d3 c8b7 f3e5",
        "d2d4 g8f6 c2c4 e7e6 g1f3 b7b6 g2g3 c8b7 f1g2 f8e7 b1c3",
        "d2d4 g8f6 c2c4 e7e6 g1f3 d7d5 b1c3 f8b4 c1g5 d5c4",
        "d2d4 g8f6 c2c4 e7e6 g1f3 d7d5 b1c3 f8e7 c1g5 e8g8 e2e3",
        "d2d4 g8f6 c2c4 e7e6 g1f3 d7d5 b1c3 f8e7 c1g5 e8g8 e2e3 b8d7 a1c1",
        "d2d4 g8f6 c2c4 e7e6 g1f3 d7d5 b1c3 f8e7 c1g5 e8g8 e2e3 b8d7 a1c1 c7c6 d1c2 a7a6",
        "d2d4 g8f6 c2c4 e7e6 g1f3 d7d5 b1c3 f8e7 c1g5 e8g8 e2e3 h7h6 g5f6",
        "d2d4 g8f6 c2c4 e7e6 g1f3 d7d5 b1c3 f8e7 c1g5 h7h6 g5h4 e8g8 e2e3",
        "d2d4 g8f6 c2c4 e7e6 g1f3 d7d5 c1g5 h7h6",
        "d2d4 g8f6 c2c4 e7e6 g1f3 f8b4 c1d2 a7a5",
        "d2d4 g8f6 c2c4 e7e6 g2g3 d7d5 f1g2 d5c4",
        "d2d4 g8f6 c2c4 e7e6 g2g3 d7d5 f1g2 d5c4 g1f3 b8c6 d1a4 f8b4",
        "d2d4 g8f6 c2c4 e7e6 g2g3 d7d5 f1g2 f8e7 g1f3",
        "d2d4 g8f6 c2c4 e7e6 g2g3 f8b4 c1d2 b4e7 f1g2 d7d5 g1f3",
        "d2d4 g8f6 c2c4 g7g6 b1c3 d7d5 c4d5 f6d5 e2e4 d5c3 b2c3 f8g7 f1c4 c7c5 g1e2 e8g8",
        "d2d4 g8f6 c2c4 g7g6 b1c3 f8g7 e2e4 d7d6 f1e2 e8g8 c1g5 a7a6",
        "d2d4 g8f6 c2c4 g7g6 b1c3 f8g7 e2e4 d7d6 f1e2 e8g8 c1g5 c7c5",
        "d2d4 g8f6 c2c4 g7g6 b1c3 f8g7 e2e4 d7d6 f1e2 e8g8 c1g5 h7h6",
        "d2d4 g8f6 c2c4 g7g6 b1c3 f8g7 e2e4 d7d6 f2f3 e8g8 g1e2",
        "d2d4 g8f6 c2c4 g7g6 b1c3 f8g7 e2e4 d7d6 g1f3 e8g8 f1e2 b8d7 e1g1 e7e5 d4d5",
        "d2d4 g8f6 c2c4 g7g6 b1c3 f8g7 e2e4 d7d6 g1f3 e8g8 f1e2 e7e5 e1g1 b8c6 d4d5 c6e7 b2b4 f6h5 f1e1",
        "d2d4 g8f6 c2c4 g7g6 b1c3 f8g7 g1f3 d7d6 g2g3 e8g8 f1g2 c7c6 e1g1 d8b6",
        "d2d4 g8f6 c2c4 g7g6 b1c3 f8g7 g1f3 e8g8 e2e3 d7d6 f1e2 b8d7 e1g1 e7e5 b2b4",
        "d2d4 g8f6 c2c4 g7g6 f2f3 d7d5",
        "d2d4 g8f6 c2c4 g7g6 g1f3 d7d5",
        "d2d4 g8f6 c2c4 g7g6 g1f3 f8g7 g2g3 e8g8 f1g2 d7d6 e1g1 b8c6 b1c3 a7a6",
        "d2d4 g8f6 c2c4 g7g6 g1f3 f8g7 g2g3 e8g8 f1g2 d7d6 e1g1 b8d7 b1c3 e7e5 e2e4",
        "d2d4 g8f6 g1f3 e7e6 c1f4",
        "d2d4 g8f6 g1f3 g7g6 c1g5 f8g7 b1d2 d7d5 e2e3 e8g8",
        "d2d4 g8f6 g1f3 g7g6 c2c4 f8g7 g2g3 e8g8 f1g2 d7d5 c4d5 f6d5 e1g1 c7c5 d4c5",
        "e2e3 e7e5 b1c3 d7d5 f2f4 e5f4 g1f3",
        "e2e4 b8c6 d2d4 d7d5 b1c3 a7a6",
        "e2e4 b8c6 d2d4 d7d5 e4d5 d8d5",
        "e2e4 b8c6 g1f3 g8f6 e4e5 f6g4 d2d4 d7d6 h2h3 g4h6 f1b5",
        "e2e4 c7c5 c2c3 g8f6 e4e5 f6d5 d2d4 c5d4",
        "e2e4 c7c5 d2d4 c5d4 c2c3 g8f6",
        "e2e4 c7c5 g1f3 b8c6 d2d4 c5d4 f3d4 d7d5",
        "e2e4 c7c5 g1f3 b8c6 d2d4 c5d4 f3d4 g8f6 b1c3 d7d6 d4e2",
        "e2e4 c7c5 g1f3 b8c6 f1b5 c6b8",
        "e2e4 c7c5 g1f3 b8c6 f1b5 g7g6 e1g1 f8g7 f1e1 e7e5 b2b4",
        "e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 c2c3",
        "e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 a7a6 f1c4",
        "e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 a7a6 f1e2 e7e5 d4b3 f8e7 e1g1 c8e6",
        "e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 a7a6 f1e2 e7e6",
        "e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 a7a6 f2f4",
        "e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 b8c6 c1g5 e7e6 d1d3",
        "e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 b8c6 f1e2",
        "e2e4 c7c5 g1f3 d7d6 f1b5 c8d7 b5d7 d8d7 c2c4",
        "e2e4 c7c5 g1f3 e7e6 c2c3 g8f6 e4e5 f6d5 d2d4 b8c6",
        "e2e4 c7c5 g1f3 e7e6 d2d4 c5d4 f3d4 b8c6 b1c3 d8c7 f1e2 a7a6 e1g1 g8f6 c1e3 f8e7 f2f4 d7d6 d1e1 e8g8",
        "e2e4 c7c5 g1f3 e7e6 d2d4 c5d4 f3d4 b8c6 b1c3 g8f6 d4b5 f8b4 b5d6",
        "e2e4 c7c5 g1f3 e7e6 d2d4 c5d4 f3d4 g8f6 b1c3 d7d6",
        "e2e4 c7c5 g1f3 e7e6 d2d4 c5d4 f3d4 g8f6 b1c3 d7d6 g2g4",
        "e2e4 c7c5 g1f3 g7g6 d2d4 f8g7 b1c3 d8a5",
        "e2e4 c7c6 d2d4 d7d5 b1c3 d5e4 c3e4 g8f6 e4f6 e7f6 f1c4",
        "e2e4 d7d5 e4d5 c7c6 d5c6 b8c6",
        "e2e4 d7d5 e4d5 c7c6 d5c6 e7e5",
        "e2e4 d7d6 d2d4 g8f6 b1c3 g7g6 f1c4",
        "e2e4 d7d6 d2d4 g8f6 b1c3 g7g6 f2f4 f8g7 g1f3 c7c5",
        "e2e4 d7d6 d2d4 g8f6 b1c3 g7g6 f2f4 f8g7 g1f3 e8g8 e4e5 f6d7 h2h4",
        "e2e4 d7d6 d2d4 g8f6 b1c3 g7g6 g1f3 f8g7 f1e2",
        "e2e4 e7e5 b1c3 b8c6 f2f4 e5f4 d2d4",
        "e2e4 e7e5 b1c3 g8f6 f1c4",
        "e2e4 e7e5 b1c3 g8f6 f1c4 f8c5 d2d3",
        "e2e4 e7e5 b1c3 g8f6 f2f4 d7d5 f4e5 f6e4 d2d3 d8h4 g2g3 e4g3 g1f3 h4h5 c3d5",
        "e2e4 e7e5 b1c3 g8f6 g2g3 f8c5 f1g2 b8c6 g1e2 d7d5 e4d5",
        "e2e4 e7e5 f1c4 g8f6 d2d4 e5d4 c2c3",
        "e2e4 e7e5 f2f4 d7d5 e4d5 e5e4 b1c3 g8f6 d1e2",
        "e2e4 e7e5 f2f4 e5f4 d1g4",
        "e2e4 e7e5 f2f4 e5f4 f1c4 b7b5",
        "e2e4 e7e5 f2f4 e5f4 f1c4 d7d5 c4d5 c7c6",
        "e2e4 e7e5 f2f4 e5f4 f1c4 d8h4 e1f1 f8c5",
        "e2e4 e7e5 f2f4 e5f4 f1c4 d8h4 e1f1 g7g5 b1c3 f8g7 g2g3 f4g3 d1f3",
        "e2e4 e7e5 f2f4 e5f4 g1f3 g7g5 d2d4 g5g4 f3e5",
        "e2e4 e7e5 f2f4 e5f4 g1f3 g7g5 f1c4 f8g7 e1g1",
        "e2e4 e7e5 f2f4 e5f4 g1f3 g7g5 f1c4 g5g4 f3e5 d8h4 e1f1 f4f3",
        "e2e4 e7e5 f2f4 e5f4 g1f3 g7g5 f1c4 g5g4 f3e5 d8h4 e1f1 g8h6",
        "e2e4 e7e5 f2f4 e5f4 g1f3 g7g5 h2h4 g5g4 f3e5 f8g7",
        "e2e4 e7e5 f2f4 e5f4 g1f3 g7g5 h2h4 g5g4 f3e5 g8f6 f1c4 d7d5 e4d5 f8d6 d2d4 f6h5 c1f4 h5f4",
        "e2e4 e7e5 f2f4 e5f4 g1f3 g7g5 h2h4 g5g4 f3e5 g8f6 f1c4 d7d5 e4d5 f8d6 e1g1 d6e5",
        "e2e4 e7e5 f2f4 e5f4 g1f3 g7g5 h2h4 g5g4 f3g5 h7h6 g5f7 e8f7 d2d4 d7d5 c1f4 d5e4 f1c4 f7g7 f4e5",
        "e2e4 e7e5 g1f3 b8c6 b1c3 g8f6 d2d4 e5d4 f3d4 f6e4",
        "e2e4 e7e5 g1f3 b8c6 b1c3 g8f6 f1b5 a7a6 b5c6",
        "e2e4 e7e5 g1f3 b8c6 b1c3 g8f6 f1b5 f8b4 e1g1 e8g8 d2d3 b4c3 b2c3 d7d5",
        "e2e4 e7e5 g1f3 b8c6 b1c3 g8f6 f3e5",
        "e2e4 e7e5 g1f3 b8c6 c2c3 f8e7",
        "e2e4 e7e5 g1f3 b8c6 d2d4 e5d4 f1c4 f8c5",
        "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6",
        "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 c6d4",
        "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 d1e2 b7b5 a4b3 f8e7 d2d4 d7d6 c2c3 c8g4",
        "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 d2d4",
        "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f6e4 d2d4 b7b5 a4b3 d7d5 d4e5 c8e6 b1d2 f8c5 d1e1",
        "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f6e4 d2d4 b7b5 a4b3 d7d5 d4e5 c8e6 c2c3",
        "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f6e4 d2d4 b7b5 a4b3 d7d5 d4e5 c8e6 c2c3 f8c5 d1d3",
        "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f6e4 d2d4 b7b5 a4b3 d7d5 d4e5 c8e6 c2c3 f8e7 f1e1 e8g8 f3d4 c6e5",
        "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f8e7 d1e2 b7b5 a4b3 d7d6",
        "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f8e7 f1e1 b7b5 a4b3 d7d6 c2c3 e8g8 h2h3 c6b8 d2d4",
        "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f8e7 f1e1 b7b5 a4b3 d7d6 d2d4",
        "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f8e7 f1e1 b7b5 a4b3 e8g8 c2c3 d7d5 e4d5 f6d5 f3e5 c6e5 e1e5 c7c6 d2d4 e7d6 e5e1 d8h4 g2g3 h4h3",
        "e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5c6 d7c6 e1g1 d8d6",
        "e2e4 e7e5 g1f3 b8c6 f1b5 c6a5",
        "e2e4 e7e5 g1f3 b8c6 f1b5 f7f5 b1c3 f5e4 c3e4 d7d5 f3e5 d5e4 e5c6 d8d5",
        "e2e4 e7e5 g1f3 b8c6 f1b5 g8e7 b1c3 g7g6",
        "e2e4 e7e5 g1f3 b8c6 f1b5 g8f6 d2d3 f8c5 c1e3",
        "e2e4 e7e5 g1f3 b8c6 f1b5 g8f6 e1g1 d7d6 d2d4 c8d7 b1c3 f8e7 c1g5",
        "e2e4 e7e5 g1f3 b8c6 f1b5 g8f6 e1g1 f6e4 d2d4 f8e7 d1e2 e4d6 b5c6 b7c6 d4e5 d6b7 b1c3 e8g8 f1e1 b7c5 f3d4 c5e6 c1e3 e6d4 e3d4 c6c5",
        "e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 b2b4 c5b4 c2c3 b4a5 d2d4 d7d6",
        "e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 b2b4 c5b4 c2c3 b4a5 d2d4 e5d4 e1g1 g8e7",
        "e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 b2b4 c5b4 c2c3 b4c5",
        "e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 b2b4 c5b6 b4b5 c6a5 f3e5 g8h6 d2d4 d7d6 c1h6 d6e5 h6g7 h8g8 c4f7 e8f7 g7e5 d8g5 b1d2",
        "e2e4 e7e5 g1f3 b8c6 f1c4 g8f6 d2d4 e5d4 e1g1 f6e4 f1e1 d7d5 c4d5 d8d5 b1c3",
        "e2e4 e7e5 g1f3 b8c6 f1c4 g8f6 f3g5 d7d5 e4d5 c6b4",
        "e2e4 e7e5 g1f3 d7d6 d2d4 c8g4 d4e5 b8d7",
        "e2e4 e7e5 g1f3 d7d6 d2d4 f7f5 b1c3",
        "e2e4 e7e5 g1f3 d7d6 d2d4 g8f6 f3g5",
        "e2e4 e7e5 g1f3 f8c5 f3e5 b8c6",
        "e2e4 e7e5 g1f3 g8f6 f3e5 d7d6",
        "e2e4 e7e5 g1f3 g8f6 f3e5 d7d6 e5f3 f6e4 d2d4 d6d5 f1d3 f8d6 e1g1 e8g8 c2c4 c7c6",
        "e2e4 e7e5 g1f3 g8f6 f3e5 d7d6 e5f7",
        "e2e4 e7e6 d2d4 d7d5 b1c3 b8c6 e4d5",
        "e2e4 e7e6 d2d4 d7d5 b1c3 f8b4 e4e5",
        "e2e4 e7e6 d2d4 d7d5 b1c3 f8b4 e4e5 c7c5 a2a3 b4c3 b2c3 g8e7 d1g4 d8c7 g4g7 h8g8 g7h7 c5d4 e1d1",
        "e2e4 e7e6 d2d4 d7d5 b1c3 f8b4 e4e5 c7c5 a2a3 b4c3 b2c3 g8e7 g1f3",
        "e2e4 e7e6 d2d4 d7d5 b1c3 g8f6 c1g5 f8b4 e4e5 h7h6 g5d2 b4c3 b2c3 f6e4 d1g4 g7g6",
        "e2e4 e7e6 d2d4 d7d5 b1c3 g8f6 c1g5 f8e7",
        "e2e4 e7e6 d2d4 d7d5 b1c3 g8f6 c1g5 f8e7 e4e5 f6d7 h2h4 c7c5",
        "e2e4 e7e6 d2d4 d7d5 b1c3 g8f6 e4e5 f6d7 f2f4 c7c5 d4c5 b8c6 a2a3 f8c5 d1g4 e8g8 g1f3 f7f6",
        "e2e4 e7e6 d2d4 d7d5 b1d2 c7c5 e4d5 e6d5 g1f3 b8c6",
        "e2e4 e7e6 d2d4 d7d5 e4d5 e6d5 c2c4",
        "e2e4 e7e6 d2d4 d7d5 e4e5 c7c5 c2c3 b8c6 g1f3 c8d7",
        "e2e4 e7e6 d2d4 d7d5 e4e5 c7c5 c2c3 d8b6 g1f3 c8d7",
        "e2e4 e7e6 d2d4 d7d5 e4e5 c7c5 d1g4 c5d4 g1f3",
        "e2e4 g8f6 b1c3 d7d5 e4d5 c7c6",
        "e2e4 g8f6 e4e5 f6d5 c2c4 d5b6 b2b3",
        "e2e4 g8f6 e4e5 f6d5 d2d4 d7d6 c2c4 d5b6 f2f4 c8f5",
        "e2e4 g8f6 e4e5 f6d5 d2d4 d7d6 c2c4 d5b6 f2f4 g7g5",
        "e2e4 g8f6 e4e5 f6d5 d2d4 d7d6 g1f3 g7g6 f1c4 d5b6 c4b3 f8g7 a2a4",
        "f2f4 d7d5 b2b3 g8f6 c1b2 d5d4 g1f3 c7c5 e2e3",
        "g1f3 d7d5 b2b3 c7c5 c2c4 d5c4 b1c3",
        "g1f3 d7d5 g2g3 c7c5 f1g2 b8c6 d2d4 g8f6 e1g1",
        "g1h3 d7d5 g2g3 e7e5 f2f4 c8h3 f1h3 e5f4 e1g1 f4g3 h2g3"
};

static const int common_opening_count = sizeof(common_openings) / sizeof(common_openings[0]);

static const char *
random_opening_string(void)
{
        uint32_t index;

        index = numbat_random() % common_opening_count;

        return common_openings[index];
}
