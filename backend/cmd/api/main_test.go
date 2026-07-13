package main

import (
	"reflect"
	"testing"
)

func TestEconomyConstants(t *testing.T) {
	if startPassBonus != 100 {
		t.Fatalf("start bonus = %d, want 100", startPassBonus)
	}
	wantCasino := [6]int{-150, -100, -50, 50, 100, 150}
	if !reflect.DeepEqual(casinoOutcomes, wantCasino) {
		t.Fatalf("casino outcomes = %v, want %v", casinoOutcomes, wantCasino)
	}
}

func TestPropertyRent(t *testing.T) {
	tests := []struct {
		price  int
		houses int
		want   int
	}{
		{price: 130, want: 43},
		{price: 160, want: 53},
		{price: 190, want: 63},
		{price: 220, want: 73},
		{price: 250, want: 83},
		{price: 280, want: 93},
		{price: 310, want: 103},
		{price: 340, want: 113},
		{price: 340, houses: 5, want: 363},
	}
	for _, test := range tests {
		if got := propertyRent(test.price, test.houses); got != test.want {
			t.Errorf("propertyRent(%d, %d) = %d, want %d", test.price, test.houses, got, test.want)
		}
	}
}

func TestHouseCostsAndFinalValues(t *testing.T) {
	wantCosts := []int{100, 150, 200, 250, 300}
	wantValues := []int{100, 250, 450, 700, 1000}
	for index := range wantCosts {
		if got := housePrice(index); got != wantCosts[index] {
			t.Errorf("housePrice(%d) = %d, want %d", index, got, wantCosts[index])
		}
		if got := housesValue(index + 1); got != wantValues[index] {
			t.Errorf("housesValue(%d) = %d, want %d", index+1, got, wantValues[index])
		}
	}
}

func TestFinalizeGameIncludesCashPropertyAndFullHouseCost(t *testing.T) {
	room := &Room{
		BoardSize: "standard",
		Players:   []Player{{ID: "player-1", Name: "Гравець"}},
		Balances:  map[string]int{"player-1": 500},
		Ownership: map[string]string{"1": "player-1"},
		Houses:    map[string]int{"1": 2},
	}

	finalizeGame(room)

	// Cell 1 costs 130; two houses return their full 100 + 150 cost.
	const wantCapital = 500 + 130 + 250
	if got := room.Capital["player-1"]; got != wantCapital {
		t.Fatalf("capital = %d, want %d", got, wantCapital)
	}
	if room.WinnerID != "player-1" {
		t.Fatalf("winner = %q, want player-1", room.WinnerID)
	}
}

func TestBankruptcyWinnerStillGetsCapitalBreakdown(t *testing.T) {
	room := &Room{
		BoardSize: "standard",
		Players:   []Player{{ID: "bankrupt"}, {ID: "winner"}},
		Balances:  map[string]int{"bankrupt": 0, "winner": 300},
		Ownership: map[string]string{"1": "winner"},
		Houses:    map[string]int{"1": 1},
	}

	markWinnerIfBankrupt(room, "bankrupt")

	if room.WinnerID != "winner" {
		t.Fatalf("winner = %q, want winner", room.WinnerID)
	}
	const wantCapital = 300 + 130 + 100
	if got := room.Capital["winner"]; got != wantCapital {
		t.Fatalf("winner capital = %d, want %d", got, wantCapital)
	}
}

func TestSettlePendingRent(t *testing.T) {
	room := &Room{
		Balances:      map[string]int{"payer": 500, "owner": 200},
		PendingRent:   75,
		PendingRentTo: "owner",
	}
	settlePendingRent(room, "payer")
	if room.Balances["payer"] != 425 {
		t.Fatalf("payer balance = %d, want 425", room.Balances["payer"])
	}
	if room.Balances["owner"] != 275 {
		t.Fatalf("owner balance = %d, want 275", room.Balances["owner"])
	}
	if room.PendingRent != 0 || room.PendingRentTo != "" {
		t.Fatalf("pending rent not cleared: %d %q", room.PendingRent, room.PendingRentTo)
	}
}
