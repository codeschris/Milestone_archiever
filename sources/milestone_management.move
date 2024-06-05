module milestone_management::milestone_management {
    use sui::event::{Self};
    use std::string::{Self, String};
    use sui::coin::{Self, Coin};
    use sui::balance::{Balance};
    use sui::sui::SUI;
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::object::{Self, ID, UID};
    use std::vector;

    // Error Constants
    const EWrongOwner: u64 = 0;
    const EAbsurdAmount: u64 = 1;
    const EInvalidContributionAmount: u64 = 2;
    const EMilestoneAlreadyCompleted: u64 = 3;
    const EInvalidCancellationRequest: u64 = 5;

    // Structs
    // Admin capability struct
    public struct AdminCap has key {
        id: UID,
    }

    // Milestone struct
    public struct Milestone has key {
        id: UID,
        description: String,
        target_amount: u64,
        collected_amount: u64,
        status: String,
        owner: address,
    }

    // Contribution struct
    public struct Contribution has key, store {
        id: UID,
        milestone_id: ID,
        amount: u64,
        balance: Balance<SUI>,
        contributor: address,
    }

    // Milestone updated event
    public struct MilestoneUpdated has copy, drop {
        milestone_id: ID,
        new_amount: u64,
        status: String,
    }

    // Initialization function
    fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCap { id: object::new(ctx) }, tx_context::sender(ctx));
    }

    // Function where admin can create milestones
    public entry fun create_milestone(
        _: &AdminCap,
        description: vector<u8>,
        target_amount: u64,
        ctx: &mut TxContext,
    ) {
        let milestone = Milestone {
            id: object::new(ctx),
            description: string::utf8(description),
            target_amount,
            collected_amount: 0,
            status: string::utf8(b"Open"),
            owner: tx_context::sender(ctx),
        };
        transfer::share_object(milestone);
    }

    // Action to contribute to a milestone
    public entry fun contribute(
        milestone: &mut Milestone,
        amount: u64,
        collateral: Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        assert!(amount > 0, EInvalidContributionAmount);
        assert!(milestone.status == string::utf8(b"Open"), EMilestoneAlreadyCompleted);

        let id_ = object::new(ctx);
        let contribution = Contribution {
            id: id_,
            milestone_id: object::uid_to_inner(&milestone.id),
            amount,
            balance: coin::into_balance(collateral),
            contributor: tx_context::sender(ctx),
        };
        milestone.collected_amount += amount;

        // Check if the milestone is fully funded
        if (milestone.collected_amount >= milestone.target_amount) {
            milestone.status = string::utf8(b"Completed");
        }

        // Emit event
        let milestone_updated = MilestoneUpdated {
            milestone_id: object::uid_to_inner(&milestone.id),
            new_amount: milestone.collected_amount,
            status: milestone.status.clone(),
        };
        event::emit<MilestoneUpdated>(milestone_updated);

        transfer::share_object(contribution);
    }

    // Action to cancel a contribution
    public entry fun cancel_contribution(
        milestone: &mut Milestone,
        contribution: Contribution,
        ctx: &mut TxContext,
    ) {
        let Contribution {
            id,
            milestone_id,
            amount,
            balance: balance_,
            contributor,
        } = contribution;
        assert!(contributor == tx_context::sender(ctx), EWrongOwner);
        assert!(object::uid_to_inner(&milestone.id) == milestone_id, EInvalidCancellationRequest);
        assert!(milestone.status != string::utf8(b"Completed"), EMilestoneAlreadyCompleted);

        // Update milestone collected amount
        milestone.collected_amount -= amount;

        if (milestone.status == string::utf8(b"Completed")) {
            milestone.status = string::utf8(b"Open");
        }

        // Emit event
        let milestone_updated = MilestoneUpdated {
            milestone_id: object::uid_to_inner(&milestone.id),
            new_amount: milestone.collected_amount,
            status: milestone.status.clone(),
        };
        event::emit<MilestoneUpdated>(milestone_updated);

        object::delete(id);

        let coin_ = coin::from_balance(balance_, ctx);
        transfer::public_transfer(coin_, tx_context::sender(ctx));
    }

    // Function to retrieve milestone status and collected amount
    public fun get_milestone_status(
        milestone: &Milestone,
    ): (u64, String) {
        (milestone.collected_amount, milestone.status.clone())
    }

    // Get balance of a contribution
    public fun get_contribution_balance(
        contribution: &Contribution,
    ): &Balance<SUI> {
        &contribution.balance
    }

    // Withdraw amount for a milestone in contribution
    public entry fun withdraw_amount(
        milestone: &mut Milestone,
        contribution: &mut Contribution,
        amount: u64,
        ctx: &mut TxContext,
    ) {
        assert!(tx_context::sender(ctx) == milestone.owner, EWrongOwner);
        assert!(milestone.status == string::utf8(b"Completed"), EMilestoneAlreadyCompleted);
        assert!(milestone.collected_amount >= amount, EInvalidContributionAmount);

        // Check for amount to withdraw not to exceed target amount of milestone
        assert!(milestone.target_amount >= amount, EAbsurdAmount);
        milestone.collected_amount -= amount;

        // Emit event
        let milestone_updated = MilestoneUpdated {
            milestone_id: object::uid_to_inner(&milestone.id),
            new_amount: milestone.collected_amount,
            status: milestone.status.clone(),
        };
        event::emit<MilestoneUpdated>(milestone_updated);

        let withdraw_amount = coin::take(&mut contribution.balance, amount, ctx);
        transfer::public_transfer(withdraw_amount, tx_context::sender(ctx));
    }

    // Additional functionality

    // Function to list all milestones
    public fun list_all_milestones(ctx: &TxContext): vector<Milestone> {
        let objects = object::list_all();
        let mut milestones = vector::empty<Milestone>();
        for obj in objects {
            if (object::type(obj) == type_of<Milestone>()) {
                let milestone: Milestone = object::read(obj);
                milestones.push_back(milestone);
            }
        }
        milestones
    }

    // Function to list all contributions
    public fun list_all_contributions(ctx: &TxContext): vector<Contribution> {
        let objects = object::list_all();
        let mut contributions = vector::empty<Contribution>();
        for obj in objects {
            if (object::type(obj) == type_of<Contribution>()) {
                let contribution: Contribution = object::read(obj);
                contributions.push_back(contribution);
            }
        }
        contributions
    }

    // Function to fetch all milestones owned by a user
    public fun get_user_milestones(user: address, ctx: &TxContext): vector<Milestone> {
        let objects = object::list_all();
        let mut milestones = vector::empty<Milestone>();
        for obj in objects {
            if (object::type(obj) == type_of<Milestone>()) {
                let milestone: Milestone = object::read(obj);
                if (milestone.owner == user) {
                    milestones.push_back(milestone);
                }
            }
        }
        milestones
    }

    // Function to fetch all contributions made by a user
    public fun get_user_contributions(user: address, ctx: &TxContext): vector<Contribution> {
        let objects = object::list_all();
        let mut contributions = vector::empty<Contribution>();
        for obj in objects {
            if (object::type(obj) == type_of<Contribution>()) {
                let contribution: Contribution = object::read(obj);
                if (contribution.contributor == user) {
                    contributions.push_back(contribution);
                }
            }
        }
        contributions
    }
}