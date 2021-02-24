pragma solidity 0.4.24;

import "@aragon/templates-shared/contracts/BaseTemplate.sol";

contract SarcophagusDaoTemplate is BaseTemplate {
    string private constant ERROR_BAD_VOTE_SETTINGS =
        "SARCOPHAGUS_DAO_BAD_VOTE_SETTINGS";

    address private constant ANY_ENTITY = address(-1);

    event SarcophagusDaoDeployed(
        address dao,
        address acl,
        address sarcophagusVotingRights,
        address voting,
        address agent,
        address finance
    );

    constructor(
        DAOFactory _daoFactory,
        ENS _ens,
        MiniMeTokenFactory _minimeTokenFactory,
        IFIFSResolvingRegistrar _aragonID
    ) public BaseTemplate(_daoFactory, _ens, _minimeTokenFactory, _aragonID) {
        _ensureAragonIdIsValid(_aragonID);
    }

    /**
     * @dev Deploy a Company DAO using a SarcoVotingRights token
     * @param _id String with the name for org, will assign `[id].aragonid.eth`
     * @param _sarcoVotingRights Address of the SARCO Voting Rights contract
     * @param _votingSettings Array of [supportRequired, minAcceptanceQuorum, voteDuration] to set up the voting app of the organization
     * @param _permissionManager The administrator that's initially granted control over the DAO's permissions
     */
    function newInstance(
        string memory _id,
        MiniMeToken _sarcoVotingRights,
        uint64[3] memory _votingSettings,
        address _permissionManager
    ) public {
        require(_sarcoVotingRights != address(0), "Invalid SARCO Voting Rights");

        _validateId(_id);
        _validateVotingSettings(_votingSettings);

        (Kernel dao, ACL acl) = _createDAO();
        (Voting voting, Agent agent, Finance finance) =
            _setupApps(
                dao,
                acl,
                _sarcoVotingRights,
                _votingSettings,
                _permissionManager
            );
        _transferRootPermissionsFromTemplateAndFinalizeDAO(
            dao,
            _permissionManager
        );
        _registerID(_id, dao);

        emit SarcophagusDaoDeployed(
            address(dao),
            address(acl),
            address(_sarcoVotingRights),
            address(voting),
            address(agent),
            address(finance)
        );
    }

    function _setupApps(
        Kernel _dao,
        ACL _acl,
        MiniMeToken _sarcoVotingRights,
        uint64[3] memory _votingSettings,
        address _permissionManager
    ) internal returns (Voting, Agent, Finance) {
        Agent agent = _installDefaultAgentApp(_dao);
        Voting voting =
            _installVotingApp(_dao, _sarcoVotingRights, _votingSettings);
        Finance finance = _installFinanceApp(_dao, agent, 0); // duration 0 uses default (30 days)

        _setupPermissions(_acl, agent, voting, finance, _permissionManager);

        return (voting, agent, finance);
    }

    function _setupPermissions(
        ACL _acl,
        Agent _agent,
        Voting _voting,
        Finance _finance,
        address _permissionManager
    ) internal {
        _createAgentPermissions(_acl, _agent, _voting, _voting);
        _createVaultPermissions(
            _acl,
            Vault(_agent),
            _finance,
            _permissionManager
        );
        _createEvmScriptsRegistryPermissions(
            _acl,
            _permissionManager,
            _permissionManager
        );
        _createVotingPermissions(
            _acl,
            _voting,
            _voting,
            ANY_ENTITY,
            _permissionManager
        );
        _createFinancePermissions(_acl, _finance, _voting, _permissionManager);
        _createFinanceCreatePaymentsPermission(_acl, _finance, _voting, _permissionManager);
    }

    function _validateVotingSettings(uint64[3] memory _votingSettings)
        private
        pure
    {
        require(_votingSettings.length == 3, ERROR_BAD_VOTE_SETTINGS);
    }
}
